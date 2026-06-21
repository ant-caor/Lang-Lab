# gbdt: gradient-boosted decision-tree ensemble inference — the dominant tabular-ML
# algorithm (XGBoost/LightGBM/CatBoost style). B=200 trees of depth D=8 over F=8
# features. Each tree is a flat complete binary tree (NODES=511): internal nodes
# 0..254 store a (feature-index, threshold) split; leaves 255..510 store a value.
# Children of node k: left=2k+1, right=2k+2. Inference: for each sample, traverse
# all B trees (exactly D compare-and-branch steps each) and sum the leaf values.
# Checksum: poly-hash of (acc+1) per sample; secondary = sum of acc values mod P.
# LCG draw order pinned: feat then thr per internal node, leafval per leaf, samples.
# All integer — no float, no ML/tree library.
#
# Elixir has no mutable array. All mutable tables live in :atomics refs (1-INDEXED:
# logical index i stored at position i+1). Arrays: feat (B*NODES), thr (B*NODES),
# leafval (B*NODES), sample (N*F). The LCG state is threaded functionally through
# the fill helpers. Inference uses a small tail-recursive helper for the D descents.
import Bitwise

defmodule Gbdt do
  @p          1_000_000_007
  @d          8
  @b          200
  @f          8
  @nodes      511  # 2^(D+1) - 1
  @leaf_start 255  # 2^D - 1

  defp lcg(s), do: band(s * 1_103_515_245 + 12_345, 0x7FFFFFFF)

  # 0-based logical accessors over 1-indexed :atomics.
  defp aget(ref, i), do: :atomics.get(ref, i + 1)
  defp aput(ref, i, v), do: :atomics.put(ref, i + 1, v)

  # --- Fill internal nodes for tree b: for each node, feat THEN thr ---
  defp fill_internal(_feat, _thr, _base, node, _state) when node >= @leaf_start, do: _state
  defp fill_internal(feat, thr, base, node, state) do
    state = lcg(state)
    aput(feat, base + node, rem(state, @f))
    state = lcg(state)
    aput(thr, base + node, rem(state, 256))
    fill_internal(feat, thr, base, node + 1, state)
  end

  # --- Fill leaves for tree b ---
  defp fill_leaves(_leafval, _base, node, state) when node >= @nodes, do: state
  defp fill_leaves(leafval, base, node, state) do
    state = lcg(state)
    aput(leafval, base + node, rem(state, 10))
    fill_leaves(leafval, base, node + 1, state)
  end

  # --- Fill all B trees ---
  defp fill_trees(_feat, _thr, _leafval, b, state) when b >= @b, do: state
  defp fill_trees(feat, thr, leafval, b, state) do
    base  = b * @nodes
    state = fill_internal(feat, thr, base, 0, state)
    state = fill_leaves(leafval, base, @leaf_start, state)
    fill_trees(feat, thr, leafval, b + 1, state)
  end

  # --- Fill sample array: N*F draws ---
  defp fill_sample(_sample, i, total, state) when i >= total, do: state
  defp fill_sample(sample, i, total, state) do
    state = lcg(state)
    aput(sample, i, rem(state, 256))
    fill_sample(sample, i + 1, total, state)
  end

  # --- Descend D times from node=0; returns final leaf node index ---
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

  # --- Accumulate B trees for sample i: sum leaf values ---
  defp accum_trees(_feat, _thr, _leafval, _sample, _sbase, b, acc) when b >= @b, do: acc
  defp accum_trees(feat, thr, leafval, sample, sbase, b, acc) do
    tbase = b * @nodes
    leaf  = descend(feat, thr, sample, tbase, sbase, 0, @d)
    accum_trees(feat, thr, leafval, sample, sbase, b + 1, acc + aget(leafval, tbase + leaf))
  end

  # --- Inference loop: for each sample i, compute acc and update h/total ---
  defp infer(_feat, _thr, _leafval, _sample, i, n, h, total) when i >= n, do: {h, total}
  defp infer(feat, thr, leafval, sample, i, n, h, total) do
    sbase = i * @f
    acc   = accum_trees(feat, thr, leafval, sample, sbase, 0, 0)
    h2     = rem(h * 31 + acc + 1, @p)
    total2 = rem(total + acc, @p)
    infer(feat, thr, leafval, sample, i + 1, n, h2, total2)
  end

  def run(n) do
    feat    = :atomics.new(@b * @nodes, signed: true)
    thr     = :atomics.new(@b * @nodes, signed: true)
    leafval = :atomics.new(@b * @nodes, signed: true)
    sample  = :atomics.new(max(n * @f, 1), signed: true)

    state = fill_trees(feat, thr, leafval, 0, 42)
    _state = fill_sample(sample, 0, n * @f, state)

    infer(feat, thr, leafval, sample, 0, n, 0, 0)
  end
end

n =
  case System.argv() do
    [a | _] -> String.to_integer(a)
    _ -> 5000
  end

{h, total} = Gbdt.run(n)
IO.puts(h)
IO.puts("gbdt(#{n}) = #{total}")
