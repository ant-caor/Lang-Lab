# lz77: a hand-written LZ77 compressor - the data-compression / sliding-window axis of the
# suite. Generate N bytes from a small alphabet (6 symbols, so matches are common) with a
# pinned LCG, then compress greedily: at each position scan the previous WINDOW bytes for
# the longest match of the lookahead (nearest distance wins ties), emit either a
# (distance, length) back-reference or a literal, advance by the match length. The whole
# token stream (markers, distances, lengths, literals) is folded into a polynomial hash.
# The hot path is a HAND-WRITTEN brute-force O(N*WINDOW) longest-match window scan - no
# compression library (zlib/gzip/LZ4), no hash-chain / suffix-tree acceleration. All integer.
#
# The scan goes from pos-1 DOWN to start (nearest distance first) and updates the best on
# STRICT > (so the closest match wins ties). Overlapping matches - where cand+len reaches
# pos - are allowed and not special-cased, exactly as in real LZ77.
#
# The input is read-index-heavy: the window scan reads in[cand+len] and in[pos+len] many
# times, so it lives in an :atomics ref - the BEAM's mutable 64-bit signed-integer array -
# for O(1) NIF reads. NOTE: :atomics is 1-INDEXED (valid positions 1..N), but the algorithm
# is 0-based, so logical byte k is stored at position k + 1. Integers are arbitrary precision
# (64-bit safe); we still apply band 0x7fffffff for the LCG mask and rem exactly. The hash
# needs 64 bits (h*31 ~ 3.1e10) - Elixir bignums cover it.
import Bitwise

defmodule Lz77 do
  @p 1_000_000_007
  @window 512
  @min_match 3
  @max_match 255
  @alpha 6

  # glibc-style LCG: 64-bit multiply, mask to 31 bits.
  defp lcg(s), do: band(s * 1_103_515_245 + 12_345, 0x7FFFFFFF)

  # 0-based logical accessor over the 1-indexed :atomics array.
  defp aget(ref, i), do: :atomics.get(ref, i + 1)

  # Fill in[0..n-1] from the LCG stream: byte = state mod ALPHA.
  defp fill(_ref, i, n, _state) when i >= n, do: :ok

  defp fill(ref, i, n, state) do
    state = lcg(state)
    :atomics.put(ref, i + 1, rem(state, @alpha))
    fill(ref, i + 1, n, state)
  end

  # Greedy compression loop, threading pos and the hash h with tail recursion.
  defp compress(_ref, n, pos, h) when pos >= n, do: h

  defp compress(ref, n, pos, h) do
    start = max(0, pos - @window)
    # scan from pos-1 DOWN to start (nearest distance first); strict > so closest wins ties.
    {best_len, best_dist} = scan(ref, n, pos, pos - 1, start, 0, 0)

    if best_len >= @min_match do
      h = rem(h * 31 + 1, @p)
      h = rem(h * 31 + best_dist, @p)
      h = rem(h * 31 + best_len, @p)
      compress(ref, n, pos + best_len, h)
    else
      h = rem(h * 31 + 0, @p)
      h = rem(h * 31 + aget(ref, pos), @p)
      compress(ref, n, pos + 1, h)
    end
  end

  # for cand = pos-1 down to start: measure the match length, update best on STRICT >.
  defp scan(_ref, _n, _pos, cand, start, best_len, best_dist) when cand < start,
    do: {best_len, best_dist}

  defp scan(ref, n, pos, cand, start, best_len, best_dist) do
    len = match_len(ref, n, cand, pos, 0)

    {best_len, best_dist} =
      if len > best_len, do: {len, pos - cand}, else: {best_len, best_dist}

    scan(ref, n, pos, cand - 1, start, best_len, best_dist)
  end

  # while pos+len < N and len < MAX_MATCH and in[cand+len] == in[pos+len]: len += 1.
  # Overlapping matches (cand+len reaching pos) are allowed - no special-casing.
  defp match_len(ref, n, cand, pos, len) do
    if pos + len < n and len < @max_match and aget(ref, cand + len) == aget(ref, pos + len) do
      match_len(ref, n, cand, pos, len + 1)
    else
      len
    end
  end

  def run(n) do
    ref = :atomics.new(max(n, 1), signed: true)
    fill(ref, 0, n, 42)
    compress(ref, n, 0, 0)
  end
end

n =
  case System.argv() do
    [a | _] -> String.to_integer(a)
    _ -> 24000
  end

IO.puts(Lz77.run(n))
IO.puts("lz77(#{n})")
