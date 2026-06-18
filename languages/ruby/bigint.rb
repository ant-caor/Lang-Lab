P = 1000000007
MASK = 0xFFFFFFFF

# Hand-rolled multi-precision factorial: limbs is a base-2^32 array (NOT a native
# bignum). Ruby's arbitrary-precision Integer is used ONLY for the single intermediate
# cur = limb*k + carry, masked back to 32 bits per limb.
def bigint(n)
  limbs = [1]  # least-significant limb first; base 2^32
  length = 1
  k = 2
  while k <= n
    carry = 0
    i = 0
    while i < length
      cur = limbs[i] * k + carry  # 64-bit-range intermediate (~2^46 here)
      limbs[i] = cur & MASK       # low 32 bits
      carry = cur >> 32           # high bits propagate
      i += 1
    end
    while carry > 0
      limbs[length] = carry & MASK
      length += 1
      carry >>= 32
    end
    k += 1
  end
  h = 0
  limbs.each do |limb|  # poly-hash, least-significant first
    h = (h * 31 + limb) % P
  end
  h
end

n = ARGV[0] ? ARGV[0].to_i : 6000
puts bigint(n)
puts "bigint(#{n})"
