# sort-search: generate N integers via a pinned LCG, sort them with a hand-written
# median-of-three quicksort (Hoare partition), then run N binary searches and fold the
# found indices into a checksum. The two classic algorithms - quicksort and binary search
# - written out explicitly (no stdlib sort/bsearch), so this measures the LANGUAGE running
# the SAME algorithm, consistent with the suite's no-stdlib-shortcut rule. All integer.
#
# Elixir has no mutable list/tuple, so the one in-place array is an :atomics ref - the
# BEAM's mutable 64-bit signed-integer array. NOTE: :atomics is 1-INDEXED (valid positions
# 1..N), but the algorithm is 0-based, so logical index i is stored at position i + 1.
# Each get/put is a NIF call, which the instruction count fairly reflects. Integers are
# arbitrary precision (64-bit safe); we still apply band 0x7fffffff and rem exactly, and
# use div/rem for every floor division.
import Bitwise

defmodule SortSearch do
  @p 1_000_000_007

  # glibc-style LCG: 64-bit multiply, mask to 31 bits.
  defp lcg_next(s), do: band(s * 1_103_515_245 + 12_345, 0x7FFFFFFF)

  # 0-based logical accessors over the 1-indexed :atomics array.
  defp aget(ref, i), do: :atomics.get(ref, i + 1)
  defp aput(ref, i, v), do: :atomics.put(ref, i + 1, v)

  # swap reads both positions, then writes both.
  defp swap(ref, i, j) do
    a = aget(ref, i)
    b = aget(ref, j)
    aput(ref, i, b)
    aput(ref, j, a)
  end

  # Fill A[0..n-1] from the LCG stream; return the final state (continued by the searches).
  defp fill(_ref, i, n, state) when i >= n, do: state

  defp fill(ref, i, n, state) do
    state = lcg_next(state)
    aput(ref, i, state)
    fill(ref, i + 1, n, state)
  end

  # median-of-three + Hoare partition, recurse both sides; depth stays ~log N.
  defp qsort(_ref, lo, hi) when lo >= hi, do: :ok

  defp qsort(ref, lo, hi) do
    mid = lo + div(hi - lo, 2)
    # the three median-of-three comparisons IN THIS ORDER
    if aget(ref, mid) < aget(ref, lo), do: swap(ref, lo, mid)
    if aget(ref, hi) < aget(ref, lo), do: swap(ref, lo, hi)
    if aget(ref, hi) < aget(ref, mid), do: swap(ref, mid, hi)
    pivot = aget(ref, mid)
    j = partition(ref, pivot, lo - 1, hi + 1)
    qsort(ref, lo, j)
    qsort(ref, j + 1, hi)
  end

  # Hoare partition loop: do i++ while A[i] < pivot; do j-- while A[j] > pivot; swap; repeat.
  defp partition(ref, pivot, i, j) do
    i = scan_up(ref, pivot, i)
    j = scan_down(ref, pivot, j)

    if i >= j do
      j
    else
      swap(ref, i, j)
      partition(ref, pivot, i, j)
    end
  end

  # do i += 1 while A[i] < pivot  (increment FIRST, then test)
  defp scan_up(ref, pivot, i) do
    i = i + 1
    if aget(ref, i) < pivot, do: scan_up(ref, pivot, i), else: i
  end

  # do j -= 1 while A[j] > pivot
  defp scan_down(ref, pivot, j) do
    j = j - 1
    if aget(ref, j) > pivot, do: scan_down(ref, pivot, j), else: j
  end

  # Hand-written binary search; INTEGER (floor) division for mid. Returns 0-based index or -1.
  defp bsearch(ref, key, lo, hi) when lo <= hi do
    mid = lo + div(hi - lo, 2)
    v = aget(ref, mid)

    cond do
      v < key -> bsearch(ref, key, mid + 1, hi)
      v > key -> bsearch(ref, key, lo, mid - 1)
      true -> mid
    end
  end

  defp bsearch(_ref, _key, _lo, _hi), do: -1

  def run(n) do
    ref = :atomics.new(max(n, 1), signed: true)
    state = fill(ref, 0, n, 42)
    qsort(ref, 0, n - 1)
    searches(ref, n, 0, state, 0)
  end

  # N binary searches, keys drawn from the sorted array (every search is a hit), folded
  # into the polynomial checksum. CONTINUE the same LCG stream (do NOT reset state).
  defp searches(_ref, n, q, _state, h) when q >= n, do: h

  defp searches(ref, n, q, state, h) do
    state = lcg_next(state)
    key = aget(ref, rem(state, n))
    idx = bsearch(ref, key, 0, n - 1)
    h = rem(h * 31 + (idx + 1), @p)
    searches(ref, n, q + 1, state, h)
  end
end

n =
  case System.argv() do
    [a | _] -> String.to_integer(a)
    _ -> 100000
  end

IO.puts(SortSearch.run(n))
IO.puts("sort-search(#{n})")
