# k-means-par: parallel scaling-track variant.
# Invocation: elixir k-means-par.exs <cores> <n>
# Decomposition: ITERS iterations; per iteration:
#   1. Parallel ASSIGNMENT: divide N points into `cores` contiguous bands.
#      Each worker computes assignments for its points (strict < lowest-index tie-break
#      preserved -- workers process points in order within their band).
#      Each worker returns:
#        - a list of {point_index, cluster_index} in ascending order (for writing assign)
#        - partial ssum list (K*D) and cnt list (K) accumulated over its band
#   2. Serial CENTROID UPDATE: merge partial sums from all workers; floor-mean;
#      empty-cluster unchanged (identical to serial).
#   After all tasks complete, write assignments into the shared :atomics array
#   (each worker wrote only its disjoint index range).
# Core-invariant: each point's assignment depends only on point coords + current centroids
# (both read-only during assignment). Band boundaries via floor-division are deterministic.
# Output is identical to the serial benchmark for cores=1,2,4.
import Bitwise

defmodule KMeansPar do
  @p 1_000_000_007
  @k 16
  @d 4
  @iters 10
  @range 256

  defp lcg(s), do: band(s * 1_103_515_245 + 12_345, 0x7FFFFFFF)

  defp aget(ref, i), do: :atomics.get(ref, i + 1)
  defp aput(ref, i, v), do: :atomics.put(ref, i + 1, v)

  defp fill(_pt, i, total, _state) when i >= total, do: :ok

  defp fill(pt, i, total, state) do
    state = lcg(state)
    aput(pt, i, rem(state, @range))
    fill(pt, i + 1, total, state)
  end

  defp init_cen(_pt, _cen, i) when i >= @k * @d, do: :ok

  defp init_cen(pt, cen, i) do
    aput(cen, i, aget(pt, i))
    init_cen(pt, cen, i + 1)
  end

  defp dist2(_pt, _cen, _pb, _cb, d, acc) when d >= @d, do: acc

  defp dist2(pt, cen, pb, cb, d, acc) do
    df = aget(pt, pb + d) - aget(cen, cb + d)
    dist2(pt, cen, pb, cb, d + 1, acc + df * df)
  end

  defp nearest(_pt, _cen, _i, k, best, _bd) when k >= @k, do: best

  defp nearest(pt, cen, i, k, best, bd) do
    dist = dist2(pt, cen, i * @d, k * @d, 0, 0)

    if bd < 0 or dist < bd do
      nearest(pt, cen, i, k + 1, k, dist)
    else
      nearest(pt, cen, i, k + 1, best, bd)
    end
  end

  # Compute dimensions sum contribution for point at pb into ssum at cluster offset sb.
  defp add_dims_list(_pt, ssum, _pb, _sb, d) when d >= @d, do: ssum

  defp add_dims_list(pt, ssum, pb, sb, d) do
    val = aget(pt, pb + d)
    ssum2 = List.update_at(ssum, sb + d, &(&1 + val))
    add_dims_list(pt, ssum2, pb, sb, d + 1)
  end

  # Process points [i_start, i_end): assign each point and accumulate partial sums.
  # Returns: {assign_list (list of cluster indices, ascending i), ssum_list (K*D), cnt_list (K)}.
  defp process_band(_pt, _cen, i, i_end, assign_acc, ssum, cnt) when i >= i_end,
    do: {Enum.reverse(assign_acc), ssum, cnt}

  defp process_band(pt, cen, i, i_end, assign_acc, ssum, cnt) do
    c = nearest(pt, cen, i, 0, 0, -1)
    cnt2 = List.update_at(cnt, c, &(&1 + 1))
    ssum2 = add_dims_list(pt, ssum, i * @d, c * @d, 0)
    process_band(pt, cen, i + 1, i_end, [c | assign_acc], ssum2, cnt2)
  end

  # Write a list of cluster indices into assign atomics starting at i_start.
  defp write_assignments(_assign, _i, []), do: :ok

  defp write_assignments(assign, i, [c | rest]) do
    aput(assign, i, c)
    write_assignments(assign, i + 1, rest)
  end

  # Merge partial sums/counts from all workers.
  defp merge_partials(partial_results) do
    ssum_init = List.duplicate(0, @k * @d)
    cnt_init = List.duplicate(0, @k)

    Enum.reduce(partial_results, {ssum_init, cnt_init}, fn {_assigns, pssum, pcnt},
                                                            {ssum, cnt} ->
      ssum2 = Enum.zip_with(ssum, pssum, fn a, b -> a + b end)
      cnt2 = Enum.zip_with(cnt, pcnt, fn a, b -> a + b end)
      {ssum2, cnt2}
    end)
  end

  defp recompute(_cen, _ssum, _cnt, k) when k >= @k, do: :ok

  defp recompute(cen, ssum, cnt, k) do
    c = Enum.at(cnt, k)
    if c > 0, do: mean_dims_list(cen, ssum, c, k * @d, 0)
    recompute(cen, ssum, cnt, k + 1)
  end

  defp mean_dims_list(_cen, _ssum, _c, _kb, d) when d >= @d, do: :ok

  defp mean_dims_list(cen, ssum, c, kb, d) do
    aput(cen, kb + d, div(Enum.at(ssum, kb + d), c))
    mean_dims_list(cen, ssum, c, kb, d + 1)
  end

  defp iterate(_pt, _cen, _assign, _cores, n, iter) when iter >= @iters, do: :ok

  defp iterate(pt, cen, assign, cores, n, iter) do
    # Parallel: each worker assigns + accumulates its band.
    tasks =
      Enum.map(0..(cores - 1), fn w ->
        i_start = div(w * n, cores)
        i_end = div((w + 1) * n, cores)
        ssum_init = List.duplicate(0, @k * @d)
        cnt_init = List.duplicate(0, @k)

        Task.async(fn ->
          process_band(pt, cen, i_start, i_end, [], ssum_init, cnt_init)
        end)
      end)

    # Collect results in band order.
    band_results = Enum.map(tasks, fn t -> Task.await(t, :infinity) end)

    # Write assignments into shared atomics (each band writes its own disjoint range).
    Enum.each(Enum.zip(0..(cores - 1), band_results), fn {w, {assigns, _ssum, _cnt}} ->
      i_start = div(w * n, cores)
      write_assignments(assign, i_start, assigns)
    end)

    # Serial centroid update.
    {merged_ssum, merged_cnt} = merge_partials(band_results)
    recompute(cen, merged_ssum, merged_cnt, 0)
    iterate(pt, cen, assign, cores, n, iter + 1)
  end

  # Serial final assignment (matches serial benchmark's assign_all).
  defp assign_all_serial(_pt, _cen, _assign, i, n) when i >= n, do: :ok

  defp assign_all_serial(pt, cen, assign, i, n) do
    best = nearest(pt, cen, i, 0, 0, -1)
    aput(assign, i, best)
    assign_all_serial(pt, cen, assign, i + 1, n)
  end

  defp hash_cen(_cen, i, h) when i >= @k * @d, do: h

  defp hash_cen(cen, i, h) do
    hash_cen(cen, i + 1, rem(h * 31 + aget(cen, i), @p))
  end

  defp hash_assign(_assign, i, n, h) when i >= n, do: h

  defp hash_assign(assign, i, n, h) do
    hash_assign(assign, i + 1, n, rem(h * 31 + aget(assign, i), @p))
  end

  def run(cores, n) do
    pt = :atomics.new(max(n * @d, 1), signed: true)
    cen = :atomics.new(@k * @d, signed: true)
    assign = :atomics.new(max(n, 1), signed: true)

    fill(pt, 0, n * @d, 42)
    init_cen(pt, cen, 0)
    t0 = System.monotonic_time(:nanosecond)
    iterate(pt, cen, assign, cores, n, 0)
    t1 = System.monotonic_time(:nanosecond)
    IO.puts(:stderr, "COMPUTE_NS #{t1 - t0}")
    # Final assignment with the final centroids, then checksum (identical to serial).
    assign_all_serial(pt, cen, assign, 0, n)
    h = hash_cen(cen, 0, 0)
    hash_assign(assign, 0, n, h)
  end
end

[cores_s, n_s] =
  case System.argv() do
    [c, n | _] -> [c, n]
    [c] -> [c, "8000"]
    _ -> ["1", "8000"]
  end

cores = String.to_integer(cores_s)
n = String.to_integer(n_s)

IO.puts(KMeansPar.run(cores, n))
IO.puts("k-means(#{n})")
