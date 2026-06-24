# gemm-par: parallel PROCESS variant of gemm (scaling track).
# Invocation: ruby gemm-par.rb <cores> <n>   (ARGV[0]=cores, ARGV[1]=n)
#
# MRI has a GVL, so the fair CPU-parallel primitive is PROCESSES via Process.fork.
# Row-band decomposition (scaling-track.md section 9): the N output rows of C are
# independent, so worker w (0-indexed) computes rows [w*N/cores, (w+1)*N/cores) using
# integer floor division (last worker reaches N). Each worker reads the FULL A and B
# (B all rows, A its own rows) and writes only its band of C, returning that band to the
# parent via a pipe. The parent reassembles the full C in row order, then computes the
# checksum single-threaded - identical to the serial gemm.
#
# Loop order i->k->j is unchanged (mandatory). No BLAS / no library matmul.
#
# Core-invariance: C[i*n+j] = sum_k A[i*n+k]*B[k*n+j] does not depend on how many workers
# there are - the owner of row i computes all k in order, same as serial. The C array is
# bit-identical for cores=1,2,4 and equal to serial; the checksum runs serially over it.

P = 1000000007

# Compute output rows [row_start, row_end) of C from A and B. Returns a flat band array
# of (row_end-row_start)*n values, in row-major order. Loop order i->k->j (pinned).
def gemm_band(a, b, n, row_start, row_end)
  c_band = Array.new((row_end - row_start) * n, 0)
  i = row_start
  while i < row_end
    li = i - row_start                # local row index within this band
    bbase = li * n
    k = 0
    while k < n
      av = a[i * n + k]
      kn = k * n
      j = 0
      while j < n
        c_band[bbase + j] += av * b[kn + j]
        j += 1
      end
      k += 1
    end
    i += 1
  end
  c_band
end

# Compute all bands across `cores` forked processes; return band outputs in band order.
# cores==1 runs inline (no fork) - a valid baseline.
def run_bands(cores, a, b, n, bands)
  return bands.map { |rs, re| gemm_band(a, b, n, rs, re) } if cores == 1

  readers = []
  bands.each do |rs, re|
    r, w = IO.pipe
    pid = Process.fork do
      r.close
      Marshal.dump(gemm_band(a, b, n, rs, re), w)
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

def gemm_par(cores, n)
  a = Array.new(n * n, 0)
  b = Array.new(n * n, 0)

  state = 42
  (n * n).times do |i|
    state = (state * 1103515245 + 12345) & 0x7fffffff
    a[i] = state % 128
  end
  (n * n).times do |i|
    state = (state * 1103515245 + 12345) & 0x7fffffff
    b[i] = state % 128
  end

  bands = (0...cores).map do |w|
    [w * n / cores, (w + 1) * n / cores]
  end

  # COMPUTE_NS region (to stderr): the parallel matmul - fork+IPC + the deterministic
  # band reassembly. Excludes the LCG data-gen above and the checksum below, so the
  # scaling track's speedup excludes interpreter startup + data-gen.
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  band_results = run_bands(cores, a, b, n, bands)
  c = Array.new(n * n, 0)
  off = 0
  band_results.each do |band|
    band.each_index { |idx| c[off + idx] = band[idx] }
    off += band.length
  end
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  $stderr.puts("COMPUTE_NS #{t1 - t0}")

  h = 0
  (n * n).times { |i| h = (h * 31 + c[i] % P) % P }
  secondary = c[n * n - 1] % P
  [h, secondary]
end

cores = ARGV[0] ? ARGV[0].to_i : 1
n = ARGV[1] ? ARGV[1].to_i : 256
h, sec = gemm_par(cores, n)
puts h
puts "gemm(#{n}) = #{sec}"
