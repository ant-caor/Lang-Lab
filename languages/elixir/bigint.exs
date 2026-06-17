# bigint: hand-rolled multi-precision arithmetic - the carry-propagation axis. Compute N! as an
# array of base-2^32 limbs by repeated bignum*smallint multiplication (each limb: cur = limb*k +
# carry; store the low 32 bits, propagate the high bits), then poly-hash the limbs least-significant
# first. The big number IS the limb array - Elixir's unbounded integers are NOT used as the bignum.
#
# Elixir has no mutable array, so the limbs live in an :atomics ref (the BEAM's mutable 64-bit
# signed-integer array). :atomics is 1-INDEXED, but the algorithm is 0-based, so logical limb i is
# stored at position i + 1; the limb count `len` is threaded through the recursion (atomics carry no
# length). Each limb is kept to 32 bits: the cur = limb*k + carry intermediate is a plain Elixir int
# (it reaches ~2^46 here, well inside 64 bits), masked back with band(cur, 0xFFFFFFFF) for the stored
# limb and shifted with bsr(cur, 32) for the carry - every limb/mask/shift done by hand.
import Bitwise

defmodule Bigint do
  @p 1_000_000_007
  @mask 0xFFFFFFFF

  # 0-based logical accessors over the 1-indexed :atomics array.
  defp aget(ref, i), do: :atomics.get(ref, i + 1)
  defp aput(ref, i, v), do: :atomics.put(ref, i + 1, v)

  # limbs *= k for k = 2..N, threading the limb count `len` through. Each pass multiplies every
  # limb by k with carry, then appends the leftover carry as new high limbs.
  defp mul_all(_ref, k, n, len) when k > n, do: len

  defp mul_all(ref, k, n, len) do
    carry = inner(ref, k, 0, len, 0)
    len = append_carry(ref, len, carry)
    mul_all(ref, k + 1, n, len)
  end

  # inner limb loop i = 0..len-1: cur = limbs[i] * k + carry; limbs[i] = cur & 0xFFFFFFFF;
  # carry = cur >> 32. Returns the carry left after the last limb.
  defp inner(_ref, _k, i, len, carry) when i >= len, do: carry

  defp inner(ref, k, i, len, carry) do
    cur = aget(ref, i) * k + carry
    aput(ref, i, band(cur, @mask))
    inner(ref, k, i + 1, len, bsr(cur, 32))
  end

  # while carry > 0: limbs[len++] = carry & 0xFFFFFFFF; carry >>= 32.
  defp append_carry(_ref, len, 0), do: len

  defp append_carry(ref, len, carry) do
    aput(ref, len, band(carry, @mask))
    append_carry(ref, len + 1, bsr(carry, 32))
  end

  # poly-hash every limb least-significant first: h = (h*31 + limb) mod P. h*31 plus a 32-bit limb
  # stays under ~3.5e10, comfortably inside a 64-bit-safe Elixir int.
  defp hash(_ref, i, len, h) when i >= len, do: h
  defp hash(ref, i, len, h), do: hash(ref, i + 1, len, rem(h * 31 + aget(ref, i), @p))

  def run(n) do
    # N! has ~N entries of slack; size like the reference C (N + 64) and start with limbs = [1].
    ref = :atomics.new(n + 64, signed: true)
    aput(ref, 0, 1)
    len = mul_all(ref, 2, n, 1)
    hash(ref, 0, len, 0)
  end
end

n =
  case System.argv() do
    [a | _] -> String.to_integer(a)
    _ -> 6000
  end

IO.puts(Bigint.run(n))
IO.puts("bigint(#{n})")
