# lz77: a hand-written LZ77 compressor - the data-compression / sliding-window axis.
# Generate N bytes from a 6-symbol alphabet with a pinned LCG (matches are common), then
# at each position brute-force scan the previous WINDOW bytes for the longest match
# (nearest distance wins ties: scan from pos-1 downward, update on strict >), emit either a
# (distance, length) back-reference or a literal, advance greedily, and fold the whole token
# stream into a polynomial hash. No compression library (no zlib), no hash-chain/suffix-tree
# match acceleration - the same brute-force O(N*WINDOW) longest-match search as every language.
# All integer; the only 64-bit value is the poly-hash accumulator (h*31 ~ 3.1e10).

P = 1000000007
WINDOW = 512
MIN_MATCH = 3
MAX_MATCH = 255
ALPHA = 6

def lcg(s)
  (s * 1103515245 + 12345) & 0x7fffffff
end

def lz77(n)
  data = Array.new(n, 0)
  s = 42
  i = 0
  while i < n
    s = lcg(s)
    data[i] = s % ALPHA
    i += 1
  end

  pos = 0
  h = 0
  while pos < n
    best_len = 0
    best_dist = 0
    start = pos - WINDOW
    start = 0 if start < 0
    cand = pos - 1
    while cand >= start                                 # nearest distance first
      l = 0
      while pos + l < n && l < MAX_MATCH && data[cand + l] == data[pos + l]
        l += 1
      end
      if l > best_len                                   # strict > : closest wins ties
        best_len = l
        best_dist = pos - cand
      end
      cand -= 1
    end
    if best_len >= MIN_MATCH
      h = (h * 31 + 1) % P
      h = (h * 31 + best_dist) % P
      h = (h * 31 + best_len) % P
      pos += best_len
    else
      h = (h * 31 + 0) % P
      h = (h * 31 + data[pos]) % P
      pos += 1
    end
  end
  h
end

n = ARGV[0] ? ARGV[0].to_i : 24000
puts lz77(n)
puts "lz77(#{n})"
