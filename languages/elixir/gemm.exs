# gemm: quantized integer matrix-multiply - the dominant ML inference kernel.
# Square matmul of side N (i.e. N x N matrices). Loop order i,k,j (pinned)
# so B is accessed row-sequentially. LCG fills A then B with values 0..127.
# Accumulator is 64-bit; checksum = poly-hash of C row-major mod 1e9+7.
# No BLAS / no library matmul - the explicit triple loop.
#
# Elixir has no mutable arrays, so all three matrices use :atomics (the BEAM's
# mutable 64-bit signed-integer array). :atomics is 1-INDEXED (valid positions
# 1..len); logical 0-based index x is stored at position x+1. The LCG is kept
# in recursive tail-calls; :atomics carries A, B, C.
import Bitwise

defmodule Gemm do
  @p 1_000_000_007

  defp lcg(s), do: band(s * 1_103_515_245 + 12_345, 0x7FFFFFFF)

  defp aget(ref, i), do: :atomics.get(ref, i + 1)
  defp aput(ref, i, v), do: :atomics.put(ref, i + 1, v)
  defp aadd(ref, i, v), do: :atomics.add(ref, i + 1, v)

  # Fill an :atomics array with values in 0..127 from the LCG stream.
  defp fill(_ref, i, total, state) when i >= total, do: state

  defp fill(ref, i, total, state) do
    state = lcg(state)
    aput(ref, i, rem(state, 128))
    fill(ref, i + 1, total, state)
  end

  # Inner j-loop: C[base+j] += a * B[kn+j]
  defp inner_j(_b, _c, _kn, _base, _a, j, n) when j >= n, do: :ok

  defp inner_j(b, c, kn, base, a, j, n) do
    aadd(c, base + j, a * aget(b, kn + j))
    inner_j(b, c, kn, base, a, j + 1, n)
  end

  # Middle k-loop
  defp mid_k(_a, _b, _c, _i, k, n) when k >= n, do: :ok

  defp mid_k(a, b, c, i, k, n) do
    av = aget(a, i * n + k)
    inner_j(b, c, k * n, i * n, av, 0, n)
    mid_k(a, b, c, i, k + 1, n)
  end

  # Outer i-loop
  defp outer_i(_a, _b, _c, i, n) when i >= n, do: :ok

  defp outer_i(a, b, c, i, n) do
    mid_k(a, b, c, i, 0, n)
    outer_i(a, b, c, i + 1, n)
  end

  # Checksum poly-hash over C in row-major order. Returns {h, secondary}.
  defp hash_c(_c, i, total, h) when i >= total, do: h

  defp hash_c(c, i, total, h) do
    hash_c(c, i + 1, total, rem(h * 31 + rem(aget(c, i), @p), @p))
  end

  def run(n) do
    nn = n * n
    a = :atomics.new(nn, signed: true)
    b = :atomics.new(nn, signed: true)
    c = :atomics.new(nn, signed: true)

    state = fill(a, 0, nn, 42)
    _state = fill(b, 0, nn, state)

    outer_i(a, b, c, 0, n)

    h = hash_c(c, 0, nn, 0)
    secondary = rem(aget(c, nn - 1), @p)
    {h, secondary}
  end
end

n =
  case System.argv() do
    [a | _] -> String.to_integer(a)
    _ -> 256
  end

{h, sec} = Gemm.run(n)
IO.puts(h)
IO.puts("gemm(#{n}) = #{sec}")
