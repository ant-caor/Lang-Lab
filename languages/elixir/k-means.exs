# k-means: Lloyd's clustering - the machine-learning axis of the suite. Cluster N integer
# D-dimensional points into K clusters over ITERS fixed iterations: assign each point to its
# nearest centroid (integer squared Euclidean distance), then recompute each centroid as the
# floor-mean of its members. Everything is integer (quantized-style) - deterministic, no
# floating point, so no FMA / summation-order divergence across languages. The assignment is
# the SAME O(N*K*D) brute-force scan in every language: no ML/numeric library (no Nx), no
# k-d-tree / nearest-neighbour acceleration. Pinned tie-breaks: a point ties to the
# LOWEST-index centroid (strict < while scanning); an empty cluster keeps its centroid
# unchanged. The checksum hashes the final centroids then every point's final assignment.
#
# Elixir has no mutable array, so every integer array is an :atomics ref - the BEAM's mutable
# 64-bit signed-integer array. NOTE: :atomics is 1-INDEXED (valid positions 1..len), but the
# algorithm is 0-based, so logical index x is stored at position x + 1. The arrays: `pt`
# (N*D, written once during LCG generation then read), `cen` (K*D, mutated each iteration),
# `assign` (N, mutated), and the per-iteration `ssum` (K*D) / `cnt` (K) accumulators that we
# zero at the start of every update. The loops are hand-written recursion over ranges; the
# :atomics carry all mutable state (no accumulator is threaded for them). Integers are
# arbitrary precision (64-bit safe); we still apply band 0x7fffffff for the LCG, div for the
# integer (floor) centroid mean, and rem for every modulo exactly. The hash needs 64 bits
# (h*31 ~ 3.1e10) - Elixir bignums cover it.
import Bitwise

defmodule KMeans do
  @p 1_000_000_007
  @k 16
  @d 4
  @iters 10
  @range 256

  # glibc-style LCG: 64-bit multiply, mask to 31 bits.
  defp lcg(s), do: band(s * 1_103_515_245 + 12_345, 0x7FFFFFFF)

  # 0-based logical accessors over the 1-indexed :atomics arrays.
  defp aget(ref, i), do: :atomics.get(ref, i + 1)
  defp aput(ref, i, v), do: :atomics.put(ref, i + 1, v)
  defp aadd(ref, i, v), do: :atomics.add(ref, i + 1, v)

  # 1. Fill pt[0..N*D-1] from the LCG stream: pt[i] = state mod 256.
  defp fill(_pt, i, total, _state) when i >= total, do: :ok

  defp fill(pt, i, total, state) do
    state = lcg(state)
    aput(pt, i, rem(state, @range))
    fill(pt, i + 1, total, state)
  end

  # initial centroids = first K points: cen[i] = pt[i] for i in 0..K*D-1.
  defp init_cen(_pt, _cen, i) when i >= @k * @d, do: :ok

  defp init_cen(pt, cen, i) do
    aput(cen, i, aget(pt, i))
    init_cen(pt, cen, i + 1)
  end

  # --- assignment: nearest centroid, lowest-index tie-break via strict < ---

  # for each point i in 0..n-1: assign[i] = argmin_k dist^2(pt[i], cen[k]).
  defp assign_all(_pt, _cen, _assign, i, n) when i >= n, do: :ok

  defp assign_all(pt, cen, assign, i, n) do
    best = nearest(pt, cen, i, 0, 0, -1)
    aput(assign, i, best)
    assign_all(pt, cen, assign, i + 1, n)
  end

  # Scan all K centroids for point i. bestDist starts at -1; update best ONLY when
  # bestDist < 0 (first) OR dist < bestDist (STRICT < -> ties keep the lower k).
  defp nearest(_pt, _cen, _i, k, best, _bd) when k >= @k, do: best

  defp nearest(pt, cen, i, k, best, bd) do
    dist = dist2(pt, cen, i * @d, k * @d, 0, 0)

    if bd < 0 or dist < bd do
      nearest(pt, cen, i, k + 1, k, dist)
    else
      nearest(pt, cen, i, k + 1, best, bd)
    end
  end

  # integer squared distance over D dims: sum of (pt[pb+d] - cen[cb+d])^2.
  defp dist2(_pt, _cen, _pb, _cb, d, acc) when d >= @d, do: acc

  defp dist2(pt, cen, pb, cb, d, acc) do
    df = aget(pt, pb + d) - aget(cen, cb + d)
    dist2(pt, cen, pb, cb, d + 1, acc + df * df)
  end

  # --- update: floor-mean, empty cluster unchanged ---

  # zero the ssum (K*D) and cnt (K) accumulators in place before each accumulation.
  defp zero(_ref, i, len) when i >= len, do: :ok

  defp zero(ref, i, len) do
    aput(ref, i, 0)
    zero(ref, i + 1, len)
  end

  # for each point i: cnt[assign[i]] += 1; for d: ssum[assign[i]*D+d] += pt[i*D+d].
  defp accumulate(_pt, _assign, _ssum, _cnt, i, n) when i >= n, do: :ok

  defp accumulate(pt, assign, ssum, cnt, i, n) do
    k = aget(assign, i)
    aadd(cnt, k, 1)
    add_dims(pt, ssum, i * @d, k * @d, 0)
    accumulate(pt, assign, ssum, cnt, i + 1, n)
  end

  defp add_dims(_pt, _ssum, _pb, _sb, d) when d >= @d, do: :ok

  defp add_dims(pt, ssum, pb, sb, d) do
    aadd(ssum, sb + d, aget(pt, pb + d))
    add_dims(pt, ssum, pb, sb, d + 1)
  end

  # for k in 0..K-1: if cnt[k] > 0, cen[k*D+d] = ssum[k*D+d] / cnt[k] (INTEGER floor div);
  # else leave cen[k] UNCHANGED (empty cluster).
  defp recompute(_cen, _ssum, _cnt, k) when k >= @k, do: :ok

  defp recompute(cen, ssum, cnt, k) do
    c = aget(cnt, k)
    if c > 0, do: mean_dims(cen, ssum, c, k * @d, 0)
    recompute(cen, ssum, cnt, k + 1)
  end

  defp mean_dims(_cen, _ssum, _c, _kb, d) when d >= @d, do: :ok

  defp mean_dims(cen, ssum, c, kb, d) do
    aput(cen, kb + d, div(aget(ssum, kb + d), c))
    mean_dims(cen, ssum, c, kb, d + 1)
  end

  # --- the ITERS loop ---

  defp iterate(_pt, _cen, _assign, _ssum, _cnt, n, iter) when iter >= @iters, do: :ok

  defp iterate(pt, cen, assign, ssum, cnt, n, iter) do
    assign_all(pt, cen, assign, 0, n)
    zero(ssum, 0, @k * @d)
    zero(cnt, 0, @k)
    accumulate(pt, assign, ssum, cnt, 0, n)
    recompute(cen, ssum, cnt, 0)
    iterate(pt, cen, assign, ssum, cnt, n, iter + 1)
  end

  # --- checksum: hash the K*D centroid values, then all N assignments, in that order ---

  defp hash_cen(_cen, i, h) when i >= @k * @d, do: h

  defp hash_cen(cen, i, h) do
    hash_cen(cen, i + 1, rem(h * 31 + aget(cen, i), @p))
  end

  defp hash_assign(_assign, i, n, h) when i >= n, do: h

  defp hash_assign(assign, i, n, h) do
    hash_assign(assign, i + 1, n, rem(h * 31 + aget(assign, i), @p))
  end

  def run(n) do
    pt = :atomics.new(max(n * @d, 1), signed: true)
    cen = :atomics.new(@k * @d, signed: true)
    assign = :atomics.new(max(n, 1), signed: true)
    ssum = :atomics.new(@k * @d, signed: true)
    cnt = :atomics.new(@k, signed: true)

    fill(pt, 0, n * @d, 42)
    init_cen(pt, cen, 0)
    iterate(pt, cen, assign, ssum, cnt, n, 0)
    # final assignment with the final centroids, THEN the checksum.
    assign_all(pt, cen, assign, 0, n)
    h = hash_cen(cen, 0, 0)
    hash_assign(assign, 0, n, h)
  end
end

n =
  case System.argv() do
    [a | _] -> String.to_integer(a)
    _ -> 8000
  end

IO.puts(KMeans.run(n))
IO.puts("k-means(#{n})")
