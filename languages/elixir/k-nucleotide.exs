# Count every length-K substring (k-mer, K=8) of a deterministically generated DNA
# sequence in a built-in Map keyed by the k-mer binary, then reduce the map to one
# order-independent checksum. Everything is integer (Elixir integers are arbitrary
# precision), so the mod 1000000007 is applied exactly as specified.
defmodule KNucleotide do
  @k 8
  @p 1_000_000_007

  # Integer LCG: build the DNA sequence as a binary of A/C/G/T.
  defp gen(l) do
    {seq, _seed} =
      Enum.reduce(0..(l - 1), {[], 42}, fn _i, {acc, seed} ->
        seed = rem(seed * 3877 + 29573, 139968)

        base =
          cond do
            seed < 42000 -> ?A
            seed < 70000 -> ?C
            seed < 98000 -> ?G
            true -> ?T
          end

        {[base | acc], seed}
      end)

    seq |> Enum.reverse() |> :erlang.list_to_binary()
  end

  # Count every K-mer in a built-in Map keyed by the K-character substring (binary).
  defp count(s, l) do
    Enum.reduce(0..(l - @k), %{}, fn i, m ->
      kmer = binary_part(s, i, @k)
      Map.update(m, kmer, 1, &(&1 + 1))
    end)
  end

  # Order-independent checksum: sum over the map of encode(kmer)*count mod P.
  defp encode(kmer) do
    for <<c <- kmer>>, reduce: 0 do
      e ->
        code =
          case c do
            ?A -> 0
            ?C -> 1
            ?G -> 2
            _ -> 3
          end

        e * 4 + code
    end
  end

  def run(l) do
    s = gen(l)

    s
    |> count(l)
    |> Enum.reduce(0, fn {kmer, cnt}, acc ->
      rem(acc + encode(kmer) * cnt, @p)
    end)
  end
end

l =
  case System.argv() do
    [a | _] -> String.to_integer(a)
    _ -> 100_000
  end

IO.puts(KNucleotide.run(l))
IO.puts("k-nucleotide(#{l})")
