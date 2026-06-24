# mandelbrot-par: parallel PROCESS variant of mandelbrot (scaling track).
# Invocation: ruby mandelbrot-par.rb <cores> <n>   (ARGV[0]=cores, ARGV[1]=n)
#
# MRI has a GVL, so threads do NOT give CPU parallelism. The fair CPU-parallel
# primitive is PROCESSES via Process.fork. We decompose the N output rows into
# `cores` contiguous horizontal bands (pixels are independent). Each forked worker
# counts in-set pixels for its band and returns the count to the parent through a
# pipe (Marshal.dump/load). The parent sums band counts in band order (= row order),
# which is deterministic, so the result is bit-identical to serial for any cores.
#
# FMA-contraction-proof formula preserved: t=zr*zi; zi=t+t+ci (no 2*zr*zi).

# Count in-set pixels for rows [row_start, row_end). Identical arithmetic to serial.
def count_band(n, row_start, row_end)
  count = 0
  y = row_start
  while y < row_end
    ci = 2.0 * y / n - 1.0
    x = 0
    while x < n
      cr = 2.0 * x / n - 1.5
      zr = 0.0
      zi = 0.0
      tr = 0.0
      ti = 0.0
      i = 0
      while i < 50 && tr + ti <= 4.0
        t = zr * zi
        zi = t + t + ci   # == 2*zr*zi + ci, FMA-proof
        zr = tr - ti + cr
        tr = zr * zr
        ti = zi * zi
        i += 1
      end
      count += 1 if tr + ti <= 4.0   # never escaped -> in set
      x += 1
    end
    y += 1
  end
  count
end

# Run a list of bands across `cores` forked processes; return results in band order.
# Each band is [row_start, row_end]. cores==1 runs inline (no fork).
def run_bands(cores, bands)
  return bands.map { |rs, re| yield(rs, re) } if cores == 1

  readers = []
  bands.each do |rs, re|
    r, w = IO.pipe
    pid = Process.fork do
      r.close
      result = yield(rs, re)
      Marshal.dump(result, w)
      w.close
      exit!(0)
    end
    w.close
    readers << [r, pid]
  end

  # Collect in band order so the reduction is deterministic.
  readers.map do |r, pid|
    data = r.read
    r.close
    Process.waitpid(pid)
    Marshal.load(data)
  end
end

def mandelbrot_par(cores, n)
  bands = (0...cores).map do |w|
    [w * n / cores, (w + 1) * n / cores]
  end
  # COMPUTE_NS region (to stderr): fork+IPC + the deterministic band reduction, so
  # the scaling track's speedup excludes interpreter startup + data-gen. There is no
  # data-gen here (mandelbrot is pure compute), but bracket symmetrically with the
  # other -par benchmarks: from just before the workers run to just after reassembly.
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  counts = run_bands(cores, bands) { |rs, re| count_band(n, rs, re) }
  total = counts.inject(0) { |acc, c| acc + c }   # sum in band (= row) order
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  $stderr.puts("COMPUTE_NS #{t1 - t0}")
  total
end

cores = ARGV[0] ? ARGV[0].to_i : 1
n = ARGV[1] ? ARGV[1].to_i : 256
puts mandelbrot_par(cores, n)
puts "mandelbrot(#{n})"
