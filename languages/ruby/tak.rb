$calls = 0

def tak(x, y, z)
  $calls += 1
  return tak(tak(x - 1, y, z), tak(y - 1, z, x), tak(z - 1, x, y)) if y < x
  z
end

n = ARGV[0] ? ARGV[0].to_i : 6
r = tak(3 * n, 2 * n, n)
puts $calls
puts "tak(#{n}) = #{r}"
