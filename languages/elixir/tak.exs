# tak: the Takeuchi function - the function-call / recursion-overhead axis of the suite.
# A faithful port of the naive triply-recursive C reference (languages/c/tak.c): each non-base
# node makes three recursive calls, NO memoization, NO iterative / tail-call rewrite. It touches
# no arrays and allocates nothing - the only thing it stresses is the cost of a call + return +
# a couple of integer compares/decrements. The size n maps to the classic shape tak(3n, 2n, n).
#
# The checksum is the TOTAL number of calls (an invariant of doing the identical recursion -
# evaluation is eager, so all three inner calls always run). Elixir is immutable, so instead of
# threading an accumulator through every return (which would distort the call shape), the count
# lives in a :counters reference - the BEAM's mutable integer-array, the same convention the suite
# already uses for Elixir. We increment it at function ENTRY, before the base test, exactly as the
# C `calls++` sits before the `y < x` check. Pure integer; values stay tiny (no overflow).
defmodule Tak do
  # static int tak(int x, int y, int z) { calls++; if (y < x) return tak(...); return z; }
  defp tak(calls, x, y, z) do
    :counters.add(calls, 1, 1)

    if y < x do
      tak(
        calls,
        tak(calls, x - 1, y, z),
        tak(calls, y - 1, z, x),
        tak(calls, z - 1, x, y)
      )
    else
      z
    end
  end

  def run(n) do
    calls = :counters.new(1, [:atomics])
    r = tak(calls, 3 * n, 2 * n, n)
    {:counters.get(calls, 1), r}
  end
end

n =
  case System.argv() do
    [a | _] -> String.to_integer(a)
    _ -> 6
  end

{calls, r} = Tak.run(n)
IO.puts(calls)
IO.puts("tak(#{n}) = #{r}")
