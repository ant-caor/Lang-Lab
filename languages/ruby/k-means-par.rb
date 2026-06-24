# k-means-par: parallel PROCESS variant of k-means (scaling track).
# Invocation: ruby k-means-par.rb <cores> <n>   (ARGV[0]=cores, ARGV[1]=n)
#
# MRI has a GVL, so the fair CPU-parallel primitive is PROCESSES via Process.fork.
# Per iteration the ASSIGNMENT step is embarrassingly parallel over the N points: each
# forked worker is given a contiguous band of points and the current centroids, and
# returns (assign_band, ssum_band, cnt_band) to the parent over a pipe. The parent then
# does the centroid UPDATE SERIALLY from the merged partial sums/counts (floor-mean,
# empty-cluster unchanged) - identical to the serial benchmark. The final assignment
# (after ITERS iterations) is parallelised the same way. Init is identical to serial.
#
# Core-invariance:
#   - Points are scanned in the same order within each band (workers keep point order).
#   - Strict-< tie-break is preserved per-point (lowest-k wins); no cross-point ordering.
#   - The centroid update is fully serial, so centroids are bit-identical each iteration.
#   - assign[] is assembled from bands in band (= point) order before checksumming.
#   - The checksum iterates cen[] then assign[] in the same order as serial.

P = 1000000007
K = 16
D = 4
ITERS = 10
RANGE = 256

# Assign points [pt_start, pt_end) to their nearest centroid (strict-< tie-break) and
# accumulate per-cluster partial sums + counts. Returns [assign_b, ssum_b, cnt_b].
def assign_band(pt, cen, pt_start, pt_end)
  band_n = pt_end - pt_start
  assign_b = Array.new(band_n, 0)
  ssum_b = Array.new(K * D, 0)
  cnt_b = Array.new(K, 0)

  ii = 0
  while ii < band_n
    i = pt_start + ii
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
    assign_b[ii] = best
    cnt_b[best] += 1
    kb = best * D
    d = 0
    while d < D
      ssum_b[kb + d] += pt[base + d]
      d += 1
    end
    ii += 1
  end

  [assign_b, ssum_b, cnt_b]
end

# Run the assignment over `cores` forked workers; return results in band order.
# cores==1 runs inline (no fork).
def run_assign(cores, pt, cen, bands)
  return bands.map { |ps, pe| assign_band(pt, cen, ps, pe) } if cores == 1

  readers = []
  bands.each do |ps, pe|
    r, w = IO.pipe
    pid = Process.fork do
      r.close
      Marshal.dump(assign_band(pt, cen, ps, pe), w)
      w.close
      exit!(0)
    end
    w.close
    readers << [r, pid]
  end

  readers.map do |r, pid|
    data = r.read
    r.close
    Process.waitpid(pid)
    Marshal.load(data)
  end
end

def k_means_par(cores, n)
  # 1. Generate N integer D-dimensional points with the pinned LCG (identical to serial).
  pt = Array.new(n * D, 0)
  state = 42
  (n * D).times do |i|
    state = (state * 1103515245 + 12345) & 0x7fffffff
    pt[i] = state % RANGE
  end
  cen = pt[0, K * D]                    # initial centroids = first K points

  bands = (0...cores).map do |w|
    [w * n / cores, (w + 1) * n / cores]
  end

  # COMPUTE_NS region (to stderr): the ITERS iterations (parallel assign fork+IPC +
  # the serial partial-sum merge + serial floor-mean centroid update) plus the final
  # parallel assignment + reassembly. Excludes the LCG data-gen / centroid init above
  # and the checksum below, so the scaling track's speedup excludes interpreter startup
  # + data-gen. The serial merge/update IS counted: it is the parallel algorithm's cost.
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)

  # 2. ITERS iterations of parallel assign + serial centroid update.
  ITERS.times do
    results = run_assign(cores, pt, cen, bands)

    ssum = Array.new(K * D, 0)          # merge partial sums/counts (serial)
    cnt = Array.new(K, 0)
    results.each do |_assign_b, ssum_b, cnt_b|
      idx = 0
      while idx < K * D
        ssum[idx] += ssum_b[idx]
        idx += 1
      end
      k = 0
      while k < K
        cnt[k] += cnt_b[k]
        k += 1
      end
    end

    k = 0                               # update - floor-mean, empty unchanged
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

  # 3. Final assignment with final centroids (parallelised the same way).
  final_results = run_assign(cores, pt, cen, bands)
  assign = Array.new(n, 0)
  off = 0
  final_results.each do |assign_b, _ssum_b, _cnt_b|
    assign_b.each_index { |idx| assign[off + idx] = assign_b[idx] }
    off += assign_b.length
  end

  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  $stderr.puts("COMPUTE_NS #{t1 - t0}")

  # Checksum: identical to serial (cen[] then assign[]).
  h = 0
  cen.each { |v| h = (h * 31 + v) % P }
  n.times { |i| h = (h * 31 + assign[i]) % P }
  h
end

cores = ARGV[0] ? ARGV[0].to_i : 1
n = ARGV[1] ? ARGV[1].to_i : 8000
puts k_means_par(cores, n)
puts "k-means(#{n})"
