# gbdt-par: parallel scaling-track variant.
# Invocation: elixir gbdt-par.exs <cores> <n>
# Decomposition: partition the N samples into `cores` contiguous bands.
# Each worker traverses all B trees for its samples (trees are read-only, no contention)
# and returns a list of {h_partial, total_partial} for that band's contribution.
# The checksum is assembled serially in sample order after all workers complete.
# Core-invariant: each sample's acc is independent (reads static tree arrays + its own
# feature row). Band boundaries via floor-division are deterministic for any cores.
# Output is identical to the serial benchmark for cores=1,2,4.
import Bitwise

defmodule GbdtPar do
  @p 1_000_000_007
  @d 8
  @b 200
  @f 8
  @nodes 511
  @leaf_start 255

  defp lcg(s), do: band(s * 1_103_515_245 + 12_345, 0x7FFFFFFF)

  defp aget(ref, i), do: :atomics.get(ref, i + 1)
  defp aput(ref, i, v), do: :atomics.put(ref, i + 1, v)

  defp fill_internal(_feat, _thr, _base, node, state) when node >= @leaf_start, do: state

  defp fill_internal(feat, thr, base, node, state) do
    state = lcg(state)
    aput(feat, base + node, rem(state, @f))
    state = lcg(state)
    aput(thr, base + node, rem(state, 256))
    fill_internal(feat, thr, base, node + 1, state)
  end

  defp fill_leaves(_leafval, _base, node, state) when node >= @nodes, do: state

  defp fill_leaves(leafval, base, node, state) do
    state = lcg(state)
    aput(leafval, base + node, rem(state, 10))
    fill_leaves(leafval, base, node + 1, state)
  end

  defp fill_trees(_feat, _thr, _leafval, b, state) when b >= @b, do: state

  defp fill_trees(feat, thr, leafval, b, state) do
    base = b * @nodes
    state = fill_internal(feat, thr, base, 0, state)
    state = fill_leaves(leafval, base, @leaf_start, state)
    fill_trees(feat, thr, leafval, b + 1, state)
  end

  defp fill_sample(_sample, i, total, state) when i >= total, do: state

  defp fill_sample(sample, i, total, state) do
    state = lcg(state)
    aput(sample, i, rem(state, 256))
    fill_sample(sample, i + 1, total, state)
  end

  defp descend(_feat, _thr, _sample, _tbase, _sbase, node, 0), do: node

  defp descend(feat, thr, sample, tbase, sbase, node, depth) do
    f_idx = aget(feat, tbase + node)
    threshold = aget(thr, tbase + node)

    next_node =
      if aget(sample, sbase + f_idx) <= threshold do
        2 * node + 1
      else
        2 * node + 2
      end

    descend(feat, thr, sample, tbase, sbase, next_node, depth - 1)
  end

  defp accum_trees(_feat, _thr, _leafval, _sample, _sbase, b, acc) when b >= @b, do: acc

  defp accum_trees(feat, thr, leafval, sample, sbase, b, acc) do
    tbase = b * @nodes
    leaf = descend(feat, thr, sample, tbase, sbase, 0, @d)
    accum_trees(feat, thr, leafval, sample, sbase, b + 1, acc + aget(leafval, tbase + leaf))
  end

  # Infer for samples [i_start, i_end).
  # Returns a list of acc values (one per sample) in ascending sample order.
  defp infer_band(_feat, _thr, _leafval, _sample, i, i_end, acc_list)
       when i >= i_end,
       do: Enum.reverse(acc_list)

  defp infer_band(feat, thr, leafval, sample, i, i_end, acc_list) do
    sbase = i * @f
    acc = accum_trees(feat, thr, leafval, sample, sbase, 0, 0)
    infer_band(feat, thr, leafval, sample, i + 1, i_end, [acc | acc_list])
  end

  # Compute checksum from a flat list of acc values (in sample order).
  defp checksum([], h, total), do: {h, total}

  defp checksum([acc | rest], h, total) do
    h2 = rem(h * 31 + acc + 1, @p)
    total2 = rem(total + acc, @p)
    checksum(rest, h2, total2)
  end

  def run(cores, n) do
    feat = :atomics.new(@b * @nodes, signed: true)
    thr = :atomics.new(@b * @nodes, signed: true)
    leafval = :atomics.new(@b * @nodes, signed: true)
    sample = :atomics.new(max(n * @f, 1), signed: true)

    state = fill_trees(feat, thr, leafval, 0, 42)
    _state = fill_sample(sample, 0, n * @f, state)

    t0 = System.monotonic_time(:nanosecond)

    # Spawn one Task per band; each returns its list of acc values.
    tasks =
      Enum.map(0..(cores - 1), fn w ->
        i_start = div(w * n, cores)
        i_end = div((w + 1) * n, cores)

        Task.async(fn ->
          infer_band(feat, thr, leafval, sample, i_start, i_end, [])
        end)
      end)

    # Collect results in band order (deterministic), then concatenate into one list.
    acc_values =
      Enum.flat_map(tasks, fn task ->
        Task.await(task, :infinity)
      end)

    t1 = System.monotonic_time(:nanosecond)
    IO.puts(:stderr, "COMPUTE_NS #{t1 - t0}")

    # Serial checksum pass over all samples in order.
    checksum(acc_values, 0, 0)
  end
end

[cores_s, n_s] =
  case System.argv() do
    [c, n | _] -> [c, n]
    [c] -> [c, "5000"]
    _ -> ["1", "5000"]
  end

cores = String.to_integer(cores_s)
n = String.to_integer(n_s)

{h, total} = GbdtPar.run(cores, n)
IO.puts(h)
IO.puts("gbdt(#{n}) = #{total}")
