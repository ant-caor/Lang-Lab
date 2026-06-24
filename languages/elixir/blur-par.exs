# blur-par: parallel scaling-track variant.
# Invocation: elixir blur-par.exs <cores> <n>
# Decomposition: PASSES double-buffered passes; per pass, partition output rows into
# `cores` contiguous bands. Each worker reads the full input (including neighbour rows
# for the 3x3 stencil - read-only, no contention) and writes its disjoint output band.
# After all workers complete a pass, buffers are swapped (barrier) and the next pass begins.
# Border clamping (edge-replication) is identical to the serial benchmark.
# Core-invariant: each output pixel depends only on its 3x3 input neighbourhood (no
# cross-worker writes). Band boundaries via floor-division are deterministic for any cores.
# Output is identical to the serial benchmark for cores=1,2,4.
import Bitwise

defmodule BlurPar do
  @p 1_000_000_007
  @passes 4
  @k {1, 2, 1, 2, 4, 2, 1, 2, 1}

  defp lcg(s), do: band(s * 1_103_515_245 + 12_345, 0x7FFFFFFF)

  defp aget(ref, k), do: :atomics.get(ref, k + 1)
  defp aput(ref, k, v), do: :atomics.put(ref, k + 1, v)

  defp clamp(x, _n) when x < 0, do: 0
  defp clamp(x, n) when x >= n, do: n - 1
  defp clamp(x, _n), do: x

  defp fill(_ref, k, total, _state) when k >= total, do: :ok

  defp fill(ref, k, total, state) do
    state = lcg(state)
    aput(ref, k, rem(state, 256))
    fill(ref, k + 1, total, state)
  end

  # Stencil helpers (unchanged from serial).
  defp stencil_dj(_src, _n, _ni, _j, _di, dj, acc) when dj > 1, do: acc

  defp stencil_dj(src, n, ni, j, di, dj, acc) do
    nj = clamp(j + dj, n)
    w = elem(@k, (di + 1) * 3 + (dj + 1))
    acc = acc + w * aget(src, ni * n + nj)
    stencil_dj(src, n, ni, j, di, dj + 1, acc)
  end

  defp stencil_di(_src, _n, _i, _j, di, acc) when di > 1, do: acc

  defp stencil_di(src, n, i, j, di, acc) do
    ni = clamp(i + di, n)
    acc = stencil_dj(src, n, ni, j, di, -1, acc)
    stencil_di(src, n, i, j, di + 1, acc)
  end

  # Blur a single row band [i_start, i_end) from src into dst.
  defp blur_band_rows(_src, _dst, n, i, i_end) when i >= i_end, do: :ok

  defp blur_band_rows(src, dst, n, i, i_end) do
    blur_band_cols(src, dst, n, i, 0)
    blur_band_rows(src, dst, n, i + 1, i_end)
  end

  defp blur_band_cols(_src, _dst, n, _i, j) when j >= n, do: :ok

  defp blur_band_cols(src, dst, n, i, j) do
    acc = stencil_di(src, n, i, j, -1, 0)
    aput(dst, i * n + j, div(acc, 16))
    blur_band_cols(src, dst, n, i, j + 1)
  end

  # One parallel pass: spawn `cores` workers, each blurring its row band.
  defp parallel_pass(src, dst, n, cores) do
    tasks =
      Enum.map(0..(cores - 1), fn w ->
        i_start = div(w * n, cores)
        i_end = div((w + 1) * n, cores)
        Task.async(fn -> blur_band_rows(src, dst, n, i_start, i_end) end)
      end)

    # Barrier: wait for all workers before swapping buffers.
    Enum.each(tasks, fn task -> Task.await(task, :infinity) end)
  end

  defp passes(src, _dst, _n, _cores, pass) when pass >= @passes, do: src

  defp passes(src, dst, n, cores, pass) do
    parallel_pass(src, dst, n, cores)
    # Double-buffer swap: rebind refs, same as serial.
    passes(dst, src, n, cores, pass + 1)
  end

  defp hash(_ref, k, total, h) when k >= total, do: h

  defp hash(ref, k, total, h) do
    h = rem(h * 31 + aget(ref, k), @p)
    hash(ref, k + 1, total, h)
  end

  def run(cores, n) do
    total = n * n
    src = :atomics.new(max(total, 1), signed: true)
    dst = :atomics.new(max(total, 1), signed: true)
    fill(src, 0, total, 42)
    t0 = System.monotonic_time(:nanosecond)
    final = passes(src, dst, n, cores, 0)
    t1 = System.monotonic_time(:nanosecond)
    IO.puts(:stderr, "COMPUTE_NS #{t1 - t0}")
    hash(final, 0, total, 0)
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

IO.puts(BlurPar.run(cores, n))
IO.puts("blur(#{n})")
