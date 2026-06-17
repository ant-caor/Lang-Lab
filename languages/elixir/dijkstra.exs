# dijkstra: single-source shortest paths on a deterministically generated weighted digraph,
# using a HAND-WRITTEN binary min-heap (no stdlib priority queue / :gb_trees). The graph axis
# of the suite - it stresses the heap + adjacency-list traversal + relaxation loop.
#
# The heap stores PACKED keys: key = dist * 2^21 + node. Comparing keys as plain integers is
# exactly the (dist, node) lexicographic order, and the keys are all UNIQUE (a node is only
# re-pushed when its distance strictly improves), so the heap behaviour - and thus the
# operation count - is identical in every language. The checksum is a hash of the final
# distance array, which is unique for Dijkstra regardless of heap internals. All integer.
#
# Elixir has no mutable array, so the two mutable arrays are :atomics refs - the BEAM's mutable
# 64-bit signed-integer array. NOTE: :atomics is 1-INDEXED (valid positions 1..N), but the
# algorithm is 0-based, so logical index i is stored at position i + 1. The heap SIZE is not
# stored in the array; it is threaded through the recursive functions (hpush returns the new
# size, hpop returns {key, new_size}). Adjacency is built once as a Map (forward order). Integers
# are arbitrary precision (64-bit safe); we still apply band 0x7fffffff and div/rem exactly.
import Bitwise

defmodule Dijkstra do
  @p 1_000_000_007
  @inf bsl(1, 62)
  @deg 8
  @maxw 100
  @base 2_097_152

  # glibc-style LCG: 64-bit multiply, mask to 31 bits.
  defp lcg(s), do: band(s * 1_103_515_245 + 12_345, 0x7FFFFFFF)

  # 0-based logical accessors over the 1-indexed :atomics arrays.
  defp aget(ref, i), do: :atomics.get(ref, i + 1)
  defp aput(ref, i, v), do: :atomics.put(ref, i + 1, v)

  # --- hand-written binary min-heap of packed int64 keys (all keys distinct) ---

  # push: append at index `sz`, then sift up while parent > child. Returns the new size.
  defp hpush(heap, sz, k) do
    aput(heap, sz, k)
    sift_up(heap, sz)
    sz + 1
  end

  defp sift_up(_heap, 0), do: :ok

  defp sift_up(heap, i) do
    p = div(i - 1, 2)

    if aget(heap, p) > aget(heap, i) do
      swap(heap, p, i)
      sift_up(heap, p)
    else
      :ok
    end
  end

  # pop: return {top, new_size}. Move last element to the root, then sift down toward the
  # smaller child while that child < current. Caller guarantees sz > 0.
  defp hpop(heap, sz) do
    top = aget(heap, 0)
    nsz = sz - 1
    aput(heap, 0, aget(heap, nsz))
    sift_down(heap, 0, nsz)
    {top, nsz}
  end

  defp sift_down(heap, i, sz) do
    l = 2 * i + 1
    r = 2 * i + 2
    m = if l < sz and aget(heap, l) < aget(heap, i), do: l, else: i
    m = if r < sz and aget(heap, r) < aget(heap, m), do: r, else: m

    if m == i do
      :ok
    else
      swap(heap, m, i)
      sift_down(heap, m, sz)
    end
  end

  defp swap(ref, i, j) do
    a = aget(ref, i)
    b = aget(ref, j)
    aput(ref, i, b)
    aput(ref, j, a)
  end

  # --- graph generation (forward / edge-generation order) ---

  # Emit M = DEG*N edges from the pinned LCG, accumulating an adjacency Map. Map.update PREPENDS
  # each {v,w}; we reverse every list afterwards to restore forward (edge-generation) order.
  defp build_adj(n, m) do
    adj =
      Enum.reduce(0..(m - 1), {%{}, 42}, fn _e, {adj, s} ->
        s = lcg(s)
        u = rem(s, n)
        s = lcg(s)
        v = rem(s, n)
        s = lcg(s)
        w = rem(s, @maxw) + 1
        {Map.update(adj, u, [{v, w}], &[{v, w} | &1]), s}
      end)
      |> elem(0)

    Map.new(adj, fn {k, list} -> {k, Enum.reverse(list)} end)
  end

  def run(n) do
    m = @deg * n
    adj = build_adj(n, m)

    # dist[0..n-1] = INF, dist[0] = 0
    dist = :atomics.new(n, signed: true)
    fill_inf(dist, 0, n)
    aput(dist, 0, 0)

    # heap can hold up to M + 1 entries; push pack(0,0) = 0.
    heap = :atomics.new(m + 1, signed: true)
    sz = hpush(heap, 0, 0)

    loop(heap, sz, dist, adj)
    checksum(dist, 0, n, 0)
  end

  defp fill_inf(_dist, i, n) when i >= n, do: :ok

  defp fill_inf(dist, i, n) do
    aput(dist, i, @inf)
    fill_inf(dist, i + 1, n)
  end

  # main extract-min / relax loop
  defp loop(_heap, 0, _dist, _adj), do: :ok

  defp loop(heap, sz, dist, adj) do
    {key, sz} = hpop(heap, sz)
    d = div(key, @base)
    u = rem(key, @base)

    if d > aget(dist, u) do
      # stale heap entry
      loop(heap, sz, dist, adj)
    else
      sz = relax(heap, sz, dist, d, Map.get(adj, u, []))
      loop(heap, sz, dist, adj)
    end
  end

  defp relax(_heap, sz, _dist, _d, []), do: sz

  defp relax(heap, sz, dist, d, [{v, w} | rest]) do
    nd = d + w

    sz =
      if nd < aget(dist, v) do
        aput(dist, v, nd)
        hpush(heap, sz, nd * @base + v)
      else
        sz
      end

    relax(heap, sz, dist, d, rest)
  end

  # polynomial hash of the distance array (unreachable -> 0).
  defp checksum(_dist, i, n, h) when i >= n, do: h

  defp checksum(dist, i, n, h) do
    di = aget(dist, i)
    di = if di < @inf, do: di, else: 0
    checksum(dist, i + 1, n, rem(h * 31 + rem(di, @p), @p))
  end
end

n =
  case System.argv() do
    [a | _] -> String.to_integer(a)
    _ -> 10000
  end

IO.puts(Dijkstra.run(n))
IO.puts("dijkstra(#{n})")
