# Faithful port of the imperative fannkuch-redux. Elixir is immutable, so tuples
# (with put_elem/elem) stand in for the mutable arrays; functional purity means
# the flip-counting copy never mutates the permutation used to advance.
defmodule Fannkuch do
  def fannkuch(n) do
    perm1 = List.to_tuple(Enum.to_list(0..(n - 1)))
    count = Tuple.duplicate(0, n)
    outer(n, perm1, count, 0, 0, 0, n)
  end

  defp outer(n, perm1, count, max_flips, checksum, perm_idx, r) do
    {count, r} = restore_count(count, r)
    flips = count_flips(perm1, 0)
    max_flips = max(max_flips, flips)
    checksum = checksum + if rem(perm_idx, 2) == 0, do: flips, else: -flips

    case next_perm(n, perm1, count, r) do
      :done -> {max_flips, checksum}
      {perm1, count, r} -> outer(n, perm1, count, max_flips, checksum, perm_idx + 1, r)
    end
  end

  defp restore_count(count, r) when r != 1,
    do: restore_count(put_elem(count, r - 1, r), r - 1)

  defp restore_count(count, r), do: {count, r}

  defp count_flips(perm, flips) do
    case elem(perm, 0) do
      0 -> flips
      k -> count_flips(reverse_prefix(perm, 0, k), flips + 1)
    end
  end

  defp reverse_prefix(perm, i, j) when i < j do
    a = elem(perm, i)
    b = elem(perm, j)
    perm |> put_elem(i, b) |> put_elem(j, a) |> reverse_prefix(i + 1, j - 1)
  end

  defp reverse_prefix(perm, _i, _j), do: perm

  defp next_perm(n, _perm1, _count, r) when r == n, do: :done

  defp next_perm(n, perm1, count, r) do
    first = elem(perm1, 0)
    perm1 = perm1 |> shift_left(0, r) |> put_elem(r, first)
    count = put_elem(count, r, elem(count, r) - 1)

    if elem(count, r) > 0 do
      {perm1, count, r}
    else
      next_perm(n, perm1, count, r + 1)
    end
  end

  defp shift_left(perm1, i, r) when i < r,
    do: perm1 |> put_elem(i, elem(perm1, i + 1)) |> shift_left(i + 1, r)

  defp shift_left(perm1, _i, _r), do: perm1
end

n =
  case System.argv() do
    [a | _] -> String.to_integer(a)
    _ -> 7
  end

{max_flips, checksum} = Fannkuch.fannkuch(n)
IO.puts(checksum)
IO.puts("Pfannkuchen(#{n}) = #{max_flips}")
