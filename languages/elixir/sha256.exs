# sha256: iterated SHA-256 - the bit-manipulation / cryptography axis of the suite. Seed a
# 32-byte digest with a pinned LCG, then apply real FIPS 180-4 SHA-256 to it N times (each
# hash is one padded 512-bit block), and reduce the final digest to a polynomial hash. The
# hot path is 32-bit rotations, XOR, shifts and modular 2^32 addition - hand-written, no
# crypto library (:crypto is forbidden), no SHA intrinsics.
#
# Elixir integers are arbitrary precision (wider than 32 bits), so every SHA-256 word must be
# kept unsigned-32-bit by MASKING with Bitwise.band(_, 0xFFFFFFFF) after every add/op; bsr is
# the logical right shift of a value already masked to 32 bits, bsl is the left shift. The
# state is tiny (8 init words + a 64-word schedule), so functional code is fine: the schedule
# is a tuple (O(1) random access) and the a..h working variables are threaded through a reduce
# over the 64 rounds. NOT e is the 32-bit complement: band(bnot(e), 0xFFFFFFFF).
import Bitwise

defmodule Sha256 do
  @p 1_000_000_007
  @mask 0xFFFFFFFF

  # standard SHA-256 init words H0 (copied exactly from the reference C)
  @h0 {0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
       0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19}

  # standard SHA-256 round constants K (copied exactly from the reference C)
  @k {0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5, 0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
      0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3, 0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
      0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC, 0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
      0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7, 0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
      0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13, 0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
      0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3, 0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
      0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5, 0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
      0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208, 0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2}

  # rotr(x, n) = (x >>> n) | (x << (32 - n)), all masked to 32 bits. x is already a 32-bit
  # value, so bsr is a logical (zero-fill) right shift; band the left part to drop overflow.
  defp rotr(x, n), do: band(bsr(x, n) ||| band(bsl(x, 32 - n), @mask), @mask)

  # build the 64-byte block from the 32-byte digest tuple: bytes 0..31 = digest; b[32]=0x80;
  # b[33..63]=0; then b[62]=1 (message length = 256 bits = 0x0100, big-endian in bytes 56..63,
  # which lands a 1 in b[62]). We never materialise the full block: build the 16 big-endian
  # words directly. Words 0..7 come from the digest words (already big-endian 32-bit), word 8
  # is the padding 0x80000000, words 9..14 are 0, and word 15 is the length 0x00000100.
  defp build_w(d) do
    base = {
      elem(d, 0), elem(d, 1), elem(d, 2), elem(d, 3),
      elem(d, 4), elem(d, 5), elem(d, 6), elem(d, 7),
      0x80000000, 0, 0, 0, 0, 0, 0, 0x00000100
    }

    extend(base, 16)
  end

  # message schedule i=16..63: s0 = rotr(w15,7) ^ rotr(w15,18) ^ (w15 >>> 3);
  # s1 = rotr(w2,17) ^ rotr(w2,19) ^ (w2 >>> 10); w[i] = w[i-16] + s0 + w[i-7] + s1 (mod 2^32).
  defp extend(w, 64), do: w

  defp extend(w, i) do
    w15 = elem(w, i - 15)
    w2 = elem(w, i - 2)
    s0 = bxor(bxor(rotr(w15, 7), rotr(w15, 18)), bsr(w15, 3))
    s1 = bxor(bxor(rotr(w2, 17), rotr(w2, 19)), bsr(w2, 10))
    wi = band(elem(w, i - 16) + s0 + elem(w, i - 7) + s1, @mask)
    extend(Tuple.append(w, wi), i + 1)
  end

  # 64 compression rounds over the working variables a..h, threaded through a reduce.
  defp compress(w) do
    h0 = @h0

    {a, b, c, d, e, f, g, h} =
      Enum.reduce(0..63, {elem(h0, 0), elem(h0, 1), elem(h0, 2), elem(h0, 3),
                          elem(h0, 4), elem(h0, 5), elem(h0, 6), elem(h0, 7)}, fn i,
                                                                                  {a, b, c, d, e,
                                                                                   f, g, h} ->
        s1 = bxor(bxor(rotr(e, 6), rotr(e, 11)), rotr(e, 25))
        ch = bxor(band(e, f), band(band(bnot(e), @mask), g))
        t1 = band(h + s1 + ch + elem(@k, i) + elem(w, i), @mask)
        s0 = bxor(bxor(rotr(a, 2), rotr(a, 13)), rotr(a, 22))
        maj = bxor(bxor(band(a, b), band(a, c)), band(b, c))
        t2 = band(s0 + maj, @mask)
        # h=g; g=f; f=e; e=d+t1; d=c; c=b; b=a; a=t1+t2
        {band(t1 + t2, @mask), a, b, c, band(d + t1, @mask), e, f, g}
      end)

    # h[0..7] += a..h (mod 2^32); the result IS the new digest words (already big-endian 32-bit).
    {
      band(elem(h0, 0) + a, @mask),
      band(elem(h0, 1) + b, @mask),
      band(elem(h0, 2) + c, @mask),
      band(elem(h0, 3) + d, @mask),
      band(elem(h0, 4) + e, @mask),
      band(elem(h0, 5) + f, @mask),
      band(elem(h0, 6) + g, @mask),
      band(elem(h0, 7) + h, @mask)
    }
  end

  # one SHA-256 of the 32-byte digest -> a new 8-word digest tuple (each word is a big-endian
  # 32-bit chunk, so storing the words IS the big-endian serialisation back to 32 bytes).
  defp sha256_32(d), do: compress(build_w(d))

  # apply SHA-256 N times in place.
  defp iterate(d, 0), do: d
  defp iterate(d, n), do: iterate(sha256_32(d), n - 1)

  # pinned LCG seed: state=42; for i in 0..31: state=(state*1103515245+12345)&0x7fffffff;
  # digest[i]=state mod 256. We pack the 32 seeded bytes straight into 8 big-endian 32-bit words.
  defp seed_word(state) do
    s1 = band(state * 1_103_515_245 + 12_345, 0x7FFFFFFF)
    b1 = rem(s1, 256)
    s2 = band(s1 * 1_103_515_245 + 12_345, 0x7FFFFFFF)
    b2 = rem(s2, 256)
    s3 = band(s2 * 1_103_515_245 + 12_345, 0x7FFFFFFF)
    b3 = rem(s3, 256)
    s4 = band(s3 * 1_103_515_245 + 12_345, 0x7FFFFFFF)
    b4 = rem(s4, 256)
    word = bor(bor(bsl(b1, 24), bsl(b2, 16)), bor(bsl(b3, 8), b4))
    {word, s4}
  end

  defp seed_words(0, _state, acc), do: Enum.reverse(acc)

  defp seed_words(n, state, acc) do
    {word, state} = seed_word(state)
    seed_words(n - 1, state, [word | acc])
  end

  def run(n) do
    digest = List.to_tuple(seed_words(8, 42, []))
    final = iterate(digest, n)

    # checksum: poly-hash h=(h*31 + byte) mod P over the final 32 bytes (the 8 words unpacked
    # big-endian). Elixir ints are 64-bit safe: h*31 (~3.1e10) cannot overflow.
    bytes =
      Enum.flat_map(0..7, fn i ->
        w = elem(final, i)
        [band(bsr(w, 24), 0xFF), band(bsr(w, 16), 0xFF), band(bsr(w, 8), 0xFF), band(w, 0xFF)]
      end)

    Enum.reduce(bytes, 0, fn byte, h -> rem(h * 31 + byte, @p) end)
  end
end

n =
  case System.argv() do
    [a | _] -> String.to_integer(a)
    _ -> 10000
  end

IO.puts(Sha256.run(n))
IO.puts("sha256(#{n})")
