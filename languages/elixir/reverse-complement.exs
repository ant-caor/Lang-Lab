# reverse-complement: generate a DNA sequence via an integer LCG, reverse it while
# complementing each base (A<->T, C<->G), then reduce it to a polynomial string hash.
# Elixir is immutable, so the buffer is a charlist (list of integer codepoints). The
# reverse-and-complement is a single hand-written left fold (:lists.foldl) that prepends
# comp(c) onto the accumulator - folding left while prepending IS the reversal, so this is
# the explicit two-pointer equivalent with NO stdlib reverse/translate. The hash is an
# explicit per-character left fold over the ASCII byte values (A=65, C=67, G=71, T=84) - no
# builtin hashCode. Everything is integer; Elixir ints are arbitrary precision (64-bit safe).
defmodule ReverseComplement do
  @im 139968
  @ia 3877
  @ic 29573
  @p 1_000_000_007

  # A<->T, C<->G; only A/C/G/T occur
  defp comp(?A), do: ?T
  defp comp(?C), do: ?G
  defp comp(?G), do: ?C
  defp comp(_), do: ?A

  # Build the DNA sequence as a charlist (mutable-buffer analogue) in forward order via the
  # integer LCG. The list is constructed on the way back up the recursion, so the head is
  # S[0] and the tail is S[L-1] - no stdlib reverse needed.
  defp gen(0, _seed), do: []

  defp gen(n, seed) do
    seed = rem(seed * @ia + @ic, @im)

    base =
      cond do
        seed < 42000 -> ?A
        seed < 70000 -> ?C
        seed < 98000 -> ?G
        true -> ?T
      end

    [base | gen(n - 1, seed)]
  end

  def run(l) do
    # seq is the forward sequence S[0..L-1].
    seq = gen(l, 42)

    # Hand-written reverse-and-complement: foldl prepends comp(c), so the result is the
    # complemented sequence in reverse order - exactly the in-place two-pointer transform.
    revcomp = :lists.foldl(fn c, acc -> [comp(c) | acc] end, [], seq)

    # Hand-written polynomial hash over the ASCII byte values, left to right. 64-bit safe
    # (arbitrary precision): h*31 (~3.1e10) cannot overflow.
    :lists.foldl(fn c, h -> rem(h * 31 + c, @p) end, 0, revcomp)
  end
end

l =
  case System.argv() do
    [a | _] -> String.to_integer(a)
    _ -> 100000
  end

IO.puts(ReverseComplement.run(l))
IO.puts("reverse-complement(#{l})")
