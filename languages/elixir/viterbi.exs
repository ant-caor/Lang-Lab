# viterbi: integer HMM sequence decoding — the classical max-plus trellis.
# S=8 states, ALPHA=4 symbols, T=size parameter. LCG (glibc-style, seed=42)
# draws trans[S*S], emit[S*ALPHA], obs[T] in that order. Forward pass is a
# loop-carried max-reduction (STRICT > tie-break: lowest i wins), followed by a
# pointer-chain backtrace. Checksum = poly-hash of (path[t]+1).
# Secondary = optimal total path score mod P. No HMM library; pure integer.
#
# Elixir has no mutable array. All mutable tables (trans, emit, obs, back, path
# and the two column double-buffers) live in :atomics refs (1-INDEXED: logical
# index i stored at position i+1). We thread the LCG state functionally through
# the fill helpers. The two viterbi columns are both :atomics; at each time step
# we fill vit_next from vit_prev then recurse with the roles swapped. After
# (T-1) swaps the "prev" ref we passed in last is the final column.
import Bitwise

defmodule Vit do
  @s     8
  @alpha 4
  @p     1_000_000_007

  defp lcg(s), do: band(s * 1_103_515_245 + 12_345, 0x7FFFFFFF)

  # 0-based logical accessors over 1-indexed :atomics.
  defp aget(ref, i), do: :atomics.get(ref, i + 1)
  defp aput(ref, i, v), do: :atomics.put(ref, i + 1, v)

  # --- Fill trans[0..S*S-1]: rem(state,100)+1 ---
  defp fill_trans(_ref, i, state) when i >= @s * @s, do: state
  defp fill_trans(ref, i, state) do
    state = lcg(state)
    aput(ref, i, rem(state, 100) + 1)
    fill_trans(ref, i + 1, state)
  end

  # --- Fill emit[0..S*ALPHA-1]: rem(state,100)+1 ---
  defp fill_emit(_ref, i, state) when i >= @s * @alpha, do: state
  defp fill_emit(ref, i, state) do
    state = lcg(state)
    aput(ref, i, rem(state, 100) + 1)
    fill_emit(ref, i + 1, state)
  end

  # --- Fill obs[0..T-1]: rem(state,ALPHA) ---
  defp fill_obs(_ref, i, t, state) when i >= t, do: state
  defp fill_obs(ref, i, t, state) do
    state = lcg(state)
    aput(ref, i, rem(state, @alpha))
    fill_obs(ref, i + 1, t, state)
  end

  # --- Initialise column 0: vit[j] = emit[j*ALPHA + obs[0]] ---
  defp init_col(_vit, _emit_r, _obs_r, j) when j >= @s, do: :ok
  defp init_col(vit, emit_r, obs_r, j) do
    aput(vit, j, aget(emit_r, j * @alpha + aget(obs_r, 0)))
    init_col(vit, emit_r, obs_r, j + 1)
  end

  # --- Inner argmax over predecessor states i=0..S-1 ---
  # STRICT >: if sc == best, keep the existing best (lower i wins).
  defp inner_argmax(_vp, _trans_r, _e, i, best, bi, _j) when i >= @s, do: {best, bi}
  defp inner_argmax(vp, trans_r, e, i, best, bi, j) do
    sc = aget(vp, i) + aget(trans_r, i * @s + j) + e
    if sc > best do
      inner_argmax(vp, trans_r, e, i + 1, sc, i, j)
    else
      inner_argmax(vp, trans_r, e, i + 1, best, bi, j)
    end
  end

  # --- Fill vit_next[j] and back[ti*S+j] for j=0..S-1 ---
  defp fill_j(_vp, _vn, _trans_r, _emit_r, _obs_r, _back, _ti, j) when j >= @s, do: :ok
  defp fill_j(vp, vn, trans_r, emit_r, obs_r, back, ti, j) do
    e = aget(emit_r, j * @alpha + aget(obs_r, ti))
    {best, bi} = inner_argmax(vp, trans_r, e, 0, -1, 0, j)
    aput(vn, j, best)
    aput(back, ti * @s + j, bi)
    fill_j(vp, vn, trans_r, emit_r, obs_r, back, ti, j + 1)
  end

  # --- Main trellis loop ti=1..T-1 with double-buffer swap ---
  # Returns the ref that holds the FINAL column (the "prev" after the last swap).
  defp trellis(vp, vn, trans_r, emit_r, obs_r, back, ti, t) when ti >= t, do: vp
  defp trellis(vp, vn, trans_r, emit_r, obs_r, back, ti, t) do
    fill_j(vp, vn, trans_r, emit_r, obs_r, back, ti, 0)
    trellis(vn, vp, trans_r, emit_r, obs_r, back, ti + 1, t)
  end

  # --- Find final best state bf (STRICT > -> lowest j wins) ---
  defp find_bf(_vit, j, bf) when j >= @s, do: bf
  defp find_bf(vit, j, bf) do
    if aget(vit, j) > aget(vit, bf),
      do: find_bf(vit, j + 1, j),
      else: find_bf(vit, j + 1, bf)
  end

  # --- Backtrace: write path[ti] from back-pointers, going backwards ---
  defp backtrace(_back, _path, ti, _st) when ti < 0, do: :ok
  defp backtrace(back, path, ti, next_st) do
    st = aget(back, (ti + 1) * @s + next_st)
    aput(path, ti, st)
    backtrace(back, path, ti - 1, st)
  end

  # --- Checksum: h = (h*31 + path[ti] + 1) % P ---
  defp checksum(_path, ti, t, h) when ti >= t, do: h
  defp checksum(path, ti, t, h) do
    checksum(path, ti + 1, t, rem(h * 31 + aget(path, ti) + 1, @p))
  end

  def run(t) do
    trans_r = :atomics.new(@s * @s, signed: true)
    emit_r  = :atomics.new(@s * @alpha, signed: true)
    obs_r   = :atomics.new(t, signed: true)

    state = fill_trans(trans_r, 0, 42)
    state = fill_emit(emit_r, 0, state)
    _state = fill_obs(obs_r, 0, t, state)

    # Two column double-buffers
    vit_a = :atomics.new(@s, signed: true)
    vit_b = :atomics.new(@s, signed: true)
    init_col(vit_a, emit_r, obs_r, 0)

    back = :atomics.new(t * @s, signed: true)

    # Run trellis. trellis/8 returns the ref holding the final column.
    final_vit =
      if t > 1 do
        trellis(vit_a, vit_b, trans_r, emit_r, obs_r, back, 1, t)
      else
        vit_a
      end

    bf = find_bf(final_vit, 1, 0)

    path = :atomics.new(t, signed: true)
    aput(path, t - 1, bf)
    if t > 1, do: backtrace(back, path, t - 2, bf)

    h = checksum(path, 0, t, 0)
    secondary = rem(aget(final_vit, bf), @p)
    {h, secondary}
  end
end

t =
  case System.argv() do
    [a | _] -> String.to_integer(a)
    _ -> 20000
  end

{h, sec} = Vit.run(t)
IO.puts(h)
IO.puts("viterbi(#{t}) = #{sec}")
