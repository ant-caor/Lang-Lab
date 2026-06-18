def fannkuch(n)
  perm1 = (0...n).to_a
  count = Array.new(n, 0)
  max_flips = 0
  checksum = 0
  perm_idx = 0
  r = n
  loop do
    while r != 1
      count[r - 1] = r
      r -= 1
    end

    perm = perm1.dup
    flips = 0
    k = perm[0]
    while k != 0
      i = 0
      j = k
      while i < j
        perm[i], perm[j] = perm[j], perm[i]
        i += 1
        j -= 1
      end
      flips += 1
      k = perm[0]
    end

    max_flips = flips if flips > max_flips
    checksum += perm_idx % 2 == 0 ? flips : -flips

    # Generate the next permutation.
    loop do
      return [max_flips, checksum] if r == n
      first = perm1[0]
      i = 0
      while i < r
        perm1[i] = perm1[i + 1]
        i += 1
      end
      perm1[r] = first
      count[r] -= 1
      break if count[r] > 0
      r += 1
    end
    perm_idx += 1
  end
end

n = ARGV[0] ? ARGV[0].to_i : 9
max_flips, checksum = fannkuch(n)
puts checksum
puts "Pfannkuchen(#{n}) = #{max_flips}"
