# polymorphism: dynamic-dispatch / virtual-call-overhead axis. N objects of K=6 concrete types in
# an unpredictable (megamorphic) order; fold acc through all of them M times via obj.apply(acc).
# Each type has its own apply() formula; the acc threads through every call so nothing can be
# hoisted (exactly N*M real dispatches). Ruby uses idiomatic duck-typed method dispatch.
# Checksum = the final accumulator. All integer.
P = 1000000007
N = 10000
K = 6

# Distinct large multipliers so the per-pass composition never reaches a fixed point: acc stays
# chaotic and the checksum depends on M (proof all N*M dispatches ran).
class T0
  def initialize(a, b, c)
    @a = a
    @b = b
    @c = c
  end

  def apply(x)
    (x * 1000003 + @a) % P
  end
end

class T1 < T0
  def apply(x)
    (x * 998273 + @b) % P
  end
end

class T2 < T0
  def apply(x)
    (x * 999983 + @c) % P
  end
end

class T3 < T0
  def apply(x)
    (x * 997879 + @a + @b) % P
  end
end

class T4 < T0
  def apply(x)
    (x * 996323 + @b * @c) % P
  end
end

class T5 < T0
  def apply(x)
    (x * 995369 + @a + @c) % P
  end
end

TYPES = [T0, T1, T2, T3, T4, T5]

def lcg(s)
  (s * 1103515245 + 12345) & 0x7fffffff
end

m = ARGV[0] ? ARGV[0].to_i : 50
s = 42
objs = []
N.times do
  s = lcg(s); t = (s >> 16) % K   # type from HIGH bits (LCG low bits correlate); all K used
  s = lcg(s); a = s % 1000
  s = lcg(s); b = s % 1000
  s = lcg(s); c = s % 1000
  objs << TYPES[t].new(a, b, c)
end
acc = 1
m.times do
  objs.each { |o| acc = o.apply(acc) }
end
puts acc
puts "polymorphism(#{m})"
