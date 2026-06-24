# blur-par: parallel PROCESS variant of blur (scaling track).
# Invocation: ruby blur-par.rb <cores> <n>   (ARGV[0]=cores, ARGV[1]=n)
#
# MRI has a GVL, so the fair CPU-parallel primitive is PROCESSES via Process.fork.
# Parallelism is per-pass: for each of PASSES double-buffered passes, divide the NxN
# output rows into `cores` contiguous bands. Each forked worker reads the FULL input
# buffer (it needs neighbour rows for the 3x3 stencil, including clamped borders) and
# returns its output rows to the parent via a pipe. The parent reassembles the full
# output buffer in row order, then swaps src/dst for the next pass. Each pass is a
# synchronisation barrier (the parent joins all workers before swapping) - matching the
# serial double-buffer swap.
#
# Border clamping (edge-replication) is identical to the serial clampi().
#
# Core-invariance: each output pixel depends only on the input buffer and the clamped
# neighbourhood, independent of core count - workers only READ neighbour rows and never
# write outside their own band.

P = 1000000007
PASSES = 4
K = [1, 2, 1, 2, 4, 2, 1, 2, 1].freeze  # 3x3, sum 16

def clampi(x, n)
  x < 0 ? 0 : (x >= n ? n - 1 : x)
end

# Compute output rows [row_start, row_end) of one blur pass from the full src buffer.
# Returns a flat band array of (row_end-row_start)*n values, in row-major order.
def blur_band(src, n, row_start, row_end)
  dst_band = Array.new((row_end - row_start) * n, 0)
  i = row_start
  while i < row_end
    li = i - row_start                # local row index within this band
    j = 0
    while j < n
      acc = 0
      [-1, 0, 1].each do |di|
        ni = clampi(i + di, n)
        [-1, 0, 1].each do |dj|
          nj = clampi(j + dj, n)
          acc += K[(di + 1) * 3 + (dj + 1)] * src[ni * n + nj]
        end
      end
      dst_band[li * n + j] = acc / 16  # integer (floor) division
      j += 1
    end
    i += 1
  end
  dst_band
end

# Run one pass across `cores` forked processes; return band outputs in band order.
# cores==1 runs inline (no fork).
def run_pass(cores, src, n, bands)
  return bands.map { |rs, re| blur_band(src, n, rs, re) } if cores == 1

  readers = []
  bands.each do |rs, re|
    r, w = IO.pipe
    pid = Process.fork do
      r.close
      Marshal.dump(blur_band(src, n, rs, re), w)
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

def blur_par(cores, n)
  src = Array.new(n * n, 0)
  s = 42
  (n * n).times do |k|
    s = (s * 1103515245 + 12345) & 0x7FFFFFFF
    src[k] = s % 256
  end

  bands = (0...cores).map do |w|
    [w * n / cores, (w + 1) * n / cores]
  end

  # COMPUTE_NS region (to stderr): the PASSES double-buffered passes - per-pass
  # fork+IPC + the deterministic band reassembly + the buffer swap (the inherent
  # per-iteration serial step). Excludes the LCG data-gen above and the checksum below,
  # so the scaling track's speedup excludes interpreter startup + data-gen.
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  PASSES.times do
    band_results = run_pass(cores, src, n, bands)
    # Reassemble dst from bands in row order (deterministic).
    dst = Array.new(n * n, 0)
    off = 0
    band_results.each do |band|
      band.each_index { |idx| dst[off + idx] = band[idx] }
      off += band.length
    end
    src = dst   # double-buffer swap: this pass's output is next pass's input
  end
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  $stderr.puts("COMPUTE_NS #{t1 - t0}")

  h = 0
  (n * n).times do |k|
    h = (h * 31 + src[k]) % P
  end
  h
end

cores = ARGV[0] ? ARGV[0].to_i : 1
n = ARGV[1] ? ARGV[1].to_i : 256
puts blur_par(cores, n)
puts "blur(#{n})"
