# k-nucleotide: count the frequency of every length-K substring (k-mer) of a
# deterministically generated DNA sequence using the built-in Hash, then reduce the
# map to one order-independent checksum.
#
# Everything is integer-deterministic (no floating point): the sequence comes from an
# integer LCG, and the checksum is sum over map entries of encode(kmer)*count mod P,
# which is independent of the Hash's iteration order. The key is the k-mer string -
# no direct-addressing shortcut on the small 4^8 key space.

K = 8
P = 1000000007
IM = 139968
IA = 3877
IC = 29573

CODE = { "A" => 0, "C" => 1, "G" => 2, "T" => 3 }

def gen(length)
  seed = 42
  chars = []
  length.times do
    seed = (seed * IA + IC) % IM
    chars <<
      if seed < 42000
        "A"
      elsif seed < 70000
        "C"
      elsif seed < 98000
        "G"
      else
        "T"
      end
  end
  chars.join
end

def k_nucleotide(length)
  s = gen(length)

  counts = Hash.new(0)
  i = 0
  last = length - K
  while i <= last
    counts[s[i, K]] += 1
    i += 1
  end

  acc = 0
  counts.each do |kmer, count|
    e = 0
    kmer.each_char { |ch| e = e * 4 + CODE[ch] }
    acc = (acc + e * count) % P
  end
  acc
end

if __FILE__ == $PROGRAM_NAME
  n = ARGV[0] ? ARGV[0].to_i : 200000
  puts k_nucleotide(n)
  puts "k-nucleotide(#{n})"
end
