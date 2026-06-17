# Each node is a heap-allocated 2-tuple {left, right}; a leaf is {nil, nil}.
defmodule BinaryTrees do
  def make(0), do: {nil, nil}
  def make(depth), do: {make(depth - 1), make(depth - 1)}

  def check({nil, _}), do: 1
  def check({l, r}), do: 1 + check(l) + check(r)

  def run(n) do
    min_depth = 4
    max_depth = max(min_depth + 2, n)
    stretch_depth = max_depth + 1

    total = check(make(stretch_depth))
    long_lived = make(max_depth)
    total = total + loop(min_depth, max_depth, min_depth, 0)
    total + check(long_lived)
  end

  defp loop(depth, max_depth, _min_depth, acc) when depth > max_depth, do: acc

  defp loop(depth, max_depth, min_depth, acc) do
    iterations = :erlang.bsl(1, max_depth - depth + min_depth)
    loop(depth + 2, max_depth, min_depth, acc + trees(iterations, depth, 0))
  end

  defp trees(0, _depth, acc), do: acc
  defp trees(i, depth, acc), do: trees(i - 1, depth, acc + check(make(depth)))
end

n =
  case System.argv() do
    [a | _] -> String.to_integer(a)
    _ -> 10
  end

IO.puts(BinaryTrees.run(n))
IO.puts("binary-trees(#{n})")
