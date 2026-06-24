# gemm-par: parallel scaling-track variant.
# Invocation: elixir gemm-par.exs <cores> <n>
# Decomposition: partition the N output rows of C into `cores` contiguous bands.
# Worker w computes rows [w*N/cores, (w+1)*N/cores). Loop order i->k->j is pinned
# (identical to serial). Each worker writes only its own rows of C (:atomics, disjoint).
# B is read-only and shared; concurrent reads are safe.
# Core-invariant: C[i*N+j] = sum_k A[i*N+k]*B[k*N+j], independent of core count.
# Checksum computed serially over full C row-major after Task.await_many.
# Output byte-identical to serial gemm for cores=1,2,4.
import Bitwise

defmodule GemmPar do
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

  # Outer i-loop over a row band [i_start, i_end).
  defp band_rows(_a, _b, _c, i, i_end, _n) when i >= i_end, do: :ok

  defp band_rows(a, b, c, i, i_end, n) do
    mid_k(a, b, c, i, 0, n)
    band_rows(a, b, c, i + 1, i_end, n)
  end

  # Checksum poly-hash over C in row-major order.
  defp hash_c(_c, i, total, h) when i >= total, do: h

  defp hash_c(c, i, total, h) do
    hash_c(c, i + 1, total, rem(h * 31 + rem(aget(c, i), @p), @p))
  end

  def run(cores, n) do
    nn = n * n
    a = :atomics.new(nn, signed: true)
    b = :atomics.new(nn, signed: true)
    c = :atomics.new(nn, signed: true)

    # Generate A then B with same LCG as serial gemm (seed=42).
    state = fill(a, 0, nn, 42)
    _state = fill(b, 0, nn, state)

    # C is already zero-initialised by :atomics.new.

    t0 = System.monotonic_time(:nanosecond)

    # Spawn one task per band; each writes only its own rows of C.
    tasks =
      Enum.map(0..(cores - 1), fn w ->
        i_start = div(w * n, cores)
        i_end = div((w + 1) * n, cores)
        Task.async(fn -> band_rows(a, b, c, i_start, i_end, n) end)
      end)

    # Barrier: wait for all workers to finish.
    Enum.each(tasks, fn task -> Task.await(task, :infinity) end)

    t1 = System.monotonic_time(:nanosecond)
    IO.puts(:stderr, "COMPUTE_NS #{t1 - t0}")

    # Serial checksum pass — identical to gemm.exs.
    h = hash_c(c, 0, nn, 0)
    secondary = rem(aget(c, nn - 1), @p)
    {h, secondary}
  end
end

[cores_s, n_s] =
  case System.argv() do
    [c, n | _] -> [c, n]
    [c] -> [c, "256"]
    _ -> ["1", "256"]
  end

cores = String.to_integer(cores_s)
n = String.to_integer(n_s)

{h, sec} = GemmPar.run(cores, n)
IO.puts(h)
IO.puts("gemm(#{n}) = #{sec}")
