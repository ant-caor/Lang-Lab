# k-means: Lloyd's clustering algorithm - the machine-learning axis of the suite. Cluster N
# integer D-dimensional points into K clusters over ITERS fixed iterations: assign each point
# to its nearest centroid (integer squared Euclidean distance), then recompute each centroid as
# the floor-mean of its members. Everything is integer (quantized-style) - deterministic, no
# floating point, so no FMA / summation-order divergence across languages.
#
# Pinned tie-breaks: a point ties to the LOWEST-index centroid (strict < while scanning); an
# empty cluster keeps its centroid unchanged. The checksum hashes the final centroids and the
# final assignment of every point.

P = 1000000007
K = 16
D = 4
ITERS = 10
RANGE = 256

def k_means(n)
  # 1. Generate N integer D-dimensional points with the pinned LCG
  pt = Array.new(n * D, 0)
  state = 42
  (n * D).times do |i|
    state = (state * 1103515245 + 12345) & 0x7fffffff
    pt[i] = state % RANGE
  end
  cen = pt[0, K * D]                      # initial centroids = first K points
  assign = Array.new(n, 0)

  # 2. ITERS iterations of assign + update
  ITERS.times do
    n.times do |i|                        # assignment - nearest centroid
      base = i * D
      best = 0
      bd = -1
      k = 0
      while k < K
        kb = k * D
        dist = 0
        d = 0
        while d < D
          df = pt[base + d] - cen[kb + d]
          dist += df * df
          d += 1
        end
        if bd < 0 || dist < bd            # STRICT < : ties go to the lowest k
          bd = dist
          best = k
        end
        k += 1
      end
      assign[i] = best
    end

    ssum = Array.new(K * D, 0)            # update - floor-mean, empty unchanged
    cnt = Array.new(K, 0)
    n.times do |i|
      k = assign[i]
      cnt[k] += 1
      base = i * D
      kb = k * D
      d = 0
      while d < D
        ssum[kb + d] += pt[base + d]
        d += 1
      end
    end
    k = 0
    while k < K
      if cnt[k] > 0
        kb = k * D
        c = cnt[k]
        d = 0
        while d < D
          cen[kb + d] = ssum[kb + d] / c  # INTEGER (floor) division
          d += 1
        end
      end
      k += 1
    end
  end

  n.times do |i|                          # final assignment with final centroids
    base = i * D
    best = 0
    bd = -1
    k = 0
    while k < K
      kb = k * D
      dist = 0
      d = 0
      while d < D
        df = pt[base + d] - cen[kb + d]
        dist += df * df
        d += 1
      end
      if bd < 0 || dist < bd
        bd = dist
        best = k
      end
      k += 1
    end
    assign[i] = best
  end

  h = 0
  cen.each { |v| h = (h * 31 + v) % P }
  n.times { |i| h = (h * 31 + assign[i]) % P }
  h
end

n = ARGV[0] ? ARGV[0].to_i : 8000
puts k_means(n)
puts "k-means(#{n})"
