# mandelbrot-par: parallel scaling-track variant.
# Invocation: elixir mandelbrot-par.exs <cores> <n>
# Decomposition: partition image rows into `cores` contiguous bands.
# Each BEAM process computes its band independently and returns a partial count.
# The final count is assembled serially by summing band counts in band order.
# Core-invariant: each pixel's computation is independent; band boundaries are
# determined by floor-division, which is deterministic for any cores value.
# Output is identical to the serial benchmark for cores=1,2,4.
defmodule MandelbrotPar do
  # Iterates z := z^2 + c up to 50 times; returns final tr+ti.
  # FMA-contraction-proof: t = zr*zi; zi = t+t+ci (not 2.0*zr*zi).
  defp iterate(50, _ci, _cr, _zr, _zi, tr, ti), do: tr + ti

  defp iterate(i, ci, cr, zr, zi, tr, ti) do
    if tr + ti <= 4.0 do
      t = zr * zi
      zi = t + t + ci
      zr = tr - ti + cr
      tr = zr * zr
      ti = zi * zi
      iterate(i + 1, ci, cr, zr, zi, tr, ti)
    else
      tr + ti
    end
  end

  # Count in-set pixels for a single column in row y.
  defp cols(x, n, ci, count) when x >= n, do: count

  defp cols(x, n, ci, count) do
    cr = 2.0 * x / n - 1.5
    count = if iterate(0, ci, cr, 0.0, 0.0, 0.0, 0.0) <= 4.0, do: count + 1, else: count
    cols(x + 1, n, ci, count)
  end

  # Count in-set pixels for rows [y_start, y_end).
  defp rows(y, y_end, n, count) when y >= y_end, do: count

  defp rows(y, y_end, n, count) do
    ci = 2.0 * y / n - 1.0
    rows(y + 1, y_end, n, cols(0, n, ci, count))
  end

  # Compute band for worker w (0-indexed). Returns the partial pixel count.
  defp band_count(w, cores, n) do
    y_start = div(w * n, cores)
    y_end = div((w + 1) * n, cores)
    rows(y_start, y_end, n, 0)
  end

  def run(cores, n) do
    t0 = System.monotonic_time(:nanosecond)

    # Spawn one Task per band; collect results in band order (deterministic).
    tasks =
      Enum.map(0..(cores - 1), fn w ->
        Task.async(fn -> band_count(w, cores, n) end)
      end)

    # Await all tasks in order, sum partial counts.
    result =
      Enum.reduce(tasks, 0, fn task, acc ->
        acc + Task.await(task, :infinity)
      end)

    t1 = System.monotonic_time(:nanosecond)
    IO.puts(:stderr, "COMPUTE_NS #{t1 - t0}")
    result
  end
end

[cores_s, n_s] =
  case System.argv() do
    [c, n | _] -> [c, n]
    [c] -> [c, "128"]
    _ -> ["1", "128"]
  end

cores = String.to_integer(cores_s)
n = String.to_integer(n_s)

IO.puts(MandelbrotPar.run(cores, n))
IO.puts("mandelbrot(#{n})")
