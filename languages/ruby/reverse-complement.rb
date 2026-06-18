# reverse-complement: generate a DNA sequence, reverse it in place while complementing
# each base (A<->T, C<->G), then reduce it to a polynomial string hash. The reverse uses a
# hand-written two-pointer loop (NOT a stdlib bulk reverse) and the hash a per-character
# loop (NOT a builtin), so this measures the language's own per-character processing -
# consistent with the suite's no-stdlib-shortcut rule. Everything is integer-deterministic.

P = 1000000007
IM = 139968
IA = 3877
IC = 29573

def comp(c) # A<->T, C<->G; only A/C/G/T occur
  return 84 if c == 65 # 'A' -> 'T'
  return 71 if c == 67 # 'C' -> 'G'
  return 67 if c == 71 # 'G' -> 'C'
  65                   # 'T' -> 'A'
end

def reverse_complement(l)
  s = Array.new(l, 0)
  seed = 42
  i = 0
  while i < l
    seed = (seed * IA + IC) % IM
    s[i] = if seed < 42000
             65 # 'A'
           elsif seed < 70000
             67 # 'C'
           elsif seed < 98000
             71 # 'G'
           else
             84 # 'T'
           end
    i += 1
  end

  i = 0
  j = l - 1
  while i < j # two-pointer reverse-and-complement, in place
    a = comp(s[i])
    s[i] = comp(s[j])
    s[j] = a
    i += 1
    j -= 1
  end
  s[i] = comp(s[i]) if i == j # middle char when L is odd

  h = 0
  k = 0
  while k < l
    h = (h * 31 + s[k]) % P
    k += 1
  end
  h
end

l = ARGV[0] ? ARGV[0].to_i : 400000
puts reverse_complement(l)
puts "reverse-complement(#{l})"
