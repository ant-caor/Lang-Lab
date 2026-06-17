# blur: a 2D image-convolution benchmark - the stencil axis of the suite. Generate a
# grayscale N x N image with a pinned LCG, then apply a 3x3 Gaussian blur kernel
# [1 2 1; 2 4 2; 1 2 1]/16 PASSES=4 times (double-buffered), with clamp (edge-replication)
# border handling, and reduce the final image to a polynomial hash. The stencil is a
# HAND-WRITTEN nested di/dj neighbourhood sum (no image library, no FFT, no SIMD). All
# integer arithmetic - deterministic, no floating point.
#
# Elixir has no mutable array, so the two image buffers are :atomics refs - the BEAM's
# mutable 64-bit signed-integer array. NOTE: :atomics is 1-INDEXED (valid positions
# 1..N*N), but the algorithm is 0-based row-major, so logical index k = i*N + j is stored
# at position k + 1. The double-buffer swap copies NOTHING: each pass reads `src` and writes
# `dst`, then we rebind {src, dst} = {dst, src} (the refs are just values), so after PASSES
# swaps `src` holds the final image. Integers are arbitrary precision (64-bit safe); we still
# apply band 0x7fffffff for the LCG, div(acc, 16) for the integer (floor) division, and rem
# for every modulo exactly. The hash needs 64 bits (h*31 ~ 3.1e10) - Elixir bignums cover it.
import Bitwise

defmodule Blur do
  @p 1_000_000_007
  @passes 4
  # 3x3 kernel, row-major: K[(di+1)*3 + (dj+1)]. Sum = 16.
  @k {1, 2, 1, 2, 4, 2, 1, 2, 1}

  # glibc-style LCG: 64-bit multiply, mask to 31 bits.
  defp lcg(s), do: band(s * 1_103_515_245 + 12_345, 0x7FFFFFFF)

  # 0-based logical accessors over the 1-indexed :atomics buffers.
  defp aget(ref, k), do: :atomics.get(ref, k + 1)
  defp aput(ref, k, v), do: :atomics.put(ref, k + 1, v)

  # clamp(x, 0, n-1): edge replication. Negative -> 0, >= n -> n-1.
  defp clamp(x, _n) when x < 0, do: 0
  defp clamp(x, n) when x >= n, do: n - 1
  defp clamp(x, _n), do: x

  # Fill src[0..n*n-1] from the LCG stream: pixel = state mod 256.
  defp fill(_ref, k, total, _state) when k >= total, do: :ok

  defp fill(ref, k, total, state) do
    state = lcg(state)
    aput(ref, k, rem(state, 256))
    fill(ref, k + 1, total, state)
  end

  # Apply @passes blur passes, double-buffered: each pass reads src, writes dst, then swap.
  # Returns the ref that holds the final image (after the last swap, that is `src`).
  defp passes(src, _dst, _n, pass) when pass >= @passes, do: src

  defp passes(src, dst, n, pass) do
    blur_rows(src, dst, n, 0)
    # double-buffer swap: rebind the refs (no copy); next pass reads the just-written dst.
    passes(dst, src, n, pass + 1)
  end

  # for i in 0..n-1
  defp blur_rows(_src, _dst, n, i) when i >= n, do: :ok

  defp blur_rows(src, dst, n, i) do
    blur_cols(src, dst, n, i, 0)
    blur_rows(src, dst, n, i + 1)
  end

  # for j in 0..n-1: hand-written 3x3 stencil, dst[i*n + j] = acc / 16 (integer division).
  defp blur_cols(_src, _dst, n, _i, j) when j >= n, do: :ok

  defp blur_cols(src, dst, n, i, j) do
    acc = stencil_di(src, n, i, j, -1, 0)
    aput(dst, i * n + j, div(acc, 16))
    blur_cols(src, dst, n, i, j + 1)
  end

  # for di in -1..1: ni = clamp(i+di, 0, n-1); accumulate the inner dj row.
  defp stencil_di(_src, _n, _i, _j, di, acc) when di > 1, do: acc

  defp stencil_di(src, n, i, j, di, acc) do
    ni = clamp(i + di, n)
    acc = stencil_dj(src, n, ni, j, di, -1, acc)
    stencil_di(src, n, i, j, di + 1, acc)
  end

  # for dj in -1..1: nj = clamp(j+dj, 0, n-1); acc += K[(di+1)*3 + (dj+1)] * src[ni*n + nj].
  defp stencil_dj(_src, _n, _ni, _j, _di, dj, acc) when dj > 1, do: acc

  defp stencil_dj(src, n, ni, j, di, dj, acc) do
    nj = clamp(j + dj, n)
    w = elem(@k, (di + 1) * 3 + (dj + 1))
    acc = acc + w * aget(src, ni * n + nj)
    stencil_dj(src, n, ni, j, di, dj + 1, acc)
  end

  # Polynomial hash over the final image (row-major): h = (h*31 + src[k]) mod P.
  defp hash(_ref, k, total, h) when k >= total, do: h

  defp hash(ref, k, total, h) do
    h = rem(h * 31 + aget(ref, k), @p)
    hash(ref, k + 1, total, h)
  end

  def run(n) do
    total = n * n
    src = :atomics.new(max(total, 1), signed: true)
    dst = :atomics.new(max(total, 1), signed: true)
    fill(src, 0, total, 42)
    final = passes(src, dst, n, 0)
    hash(final, 0, total, 0)
  end
end

n =
  case System.argv() do
    [a | _] -> String.to_integer(a)
    _ -> 256
  end

IO.puts(Blur.run(n))
IO.puts("blur(#{n})")
