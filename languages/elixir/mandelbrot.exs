# Mandelbrot set over an N x N grid of the complex plane [-1.5, 0.5] x [-1.0, 1.0].
# A pixel is "in the set" if |z| stays <= 2 (i.e. zr^2+zi^2 <= 4) through 50 iterations
# of z := z^2 + c starting from z = 0. The checksum is the count of in-set pixels.
#
# BEAM `float` is IEEE-754 double throughout. The 2*zr*zi term is written as t+t
# (t = zr*zi) instead of 2.0*zr*zi so there is NO multiply-add pattern to FMA-contract;
# t+t is bit-identical to 2.0*t. This keeps the result bit-exact across every language.
defmodule Mandelbrot do
  def run(n) do
    rows(0, n, 0)
  end

  defp rows(y, n, count) when y >= n, do: count

  defp rows(y, n, count) do
    ci = 2.0 * y / n - 1.0
    rows(y + 1, n, cols(0, n, ci, count))
  end

  defp cols(x, n, _ci, count) when x >= n, do: count

  defp cols(x, n, ci, count) do
    cr = 2.0 * x / n - 1.5
    # Never escaped through 50 iterations (tr + ti <= 4.0 still holds) -> in set.
    count = if iterate(0, ci, cr, 0.0, 0.0, 0.0, 0.0) <= 4.0, do: count + 1, else: count
    cols(x + 1, n, ci, count)
  end

  # Iterates z := z^2 + c up to 50 times, stopping early once tr + ti > 4.0.
  # Returns the final tr + ti so the caller applies the single <= 4.0 in-set test.
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
end

n =
  case System.argv() do
    [a | _] -> String.to_integer(a)
    _ -> 128
  end

IO.puts(Mandelbrot.run(n))
IO.puts("mandelbrot(#{n})")
