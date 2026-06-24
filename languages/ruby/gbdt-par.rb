# gbdt-par: parallel PROCESS variant of gbdt (scaling track).
# Invocation: ruby gbdt-par.rb <cores> <n>   (ARGV[0]=cores, ARGV[1]=n)
#
# MRI has a GVL, so the fair CPU-parallel primitive is PROCESSES via Process.fork.
# Decompose the N samples into `cores` contiguous bands. Each forked worker traverses
# all B trees for its samples (the tree arrays are read-only / static) and returns its
# per-sample acc values, in sample order, to the parent through a pipe. The parent
# concatenates the bands in index order and runs the serial poly-hash checksum loop.
#
# IMPORTANT: the poly-hash h is order-dependent (h = h*31 + acc+1), so it is NOT an
# associative reduction - workers cannot hash their bands independently. Instead each
# worker returns its raw acc values and the parent hashes the concatenated array
# serially, exactly as the serial benchmark does.
#
# Core-invariance:
#   - Tree arrays (feat, thr, leafval) are built identically and never written.
#   - Each worker computes acc[i] with the same tree traversal as serial.
#   - acc values are assembled in sample order before checksumming.
#   - The final checksum pass (h and total) is serial and identical to serial gbdt.

P          = 1000000007
D          = 8
B          = 200
F          = 8
NODES      = 511  # 2^(D+1) - 1
LEAF_START = 255  # 2^D - 1

# Infer all B trees for samples [samp_start, samp_end); return acc values in order.
def infer_band(feat, thr, leafval, sample, samp_start, samp_end)
  acc_list = Array.new(samp_end - samp_start, 0)
  i = samp_start
  while i < samp_end
    sbase = i * F
    acc = 0
    b = 0
    while b < B
      tbase = b * NODES
      node = 0
      D.times do
        if sample[sbase + feat[tbase + node]] <= thr[tbase + node]
          node = 2 * node + 1
        else
          node = 2 * node + 2
        end
      end
      acc += leafval[tbase + node]
      b += 1
    end
    acc_list[i - samp_start] = acc
    i += 1
  end
  acc_list
end

# Run inference over `cores` forked workers; return per-band acc lists in band order.
# cores==1 runs inline (no fork).
def run_infer(cores, feat, thr, leafval, sample, bands)
  return bands.map { |ss, se| infer_band(feat, thr, leafval, sample, ss, se) } if cores == 1

  readers = []
  bands.each do |ss, se|
    r, w = IO.pipe
    pid = Process.fork do
      r.close
      Marshal.dump(infer_band(feat, thr, leafval, sample, ss, se), w)
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

def gbdt_par(cores, n)
  feat    = Array.new(B * NODES, 0)
  thr     = Array.new(B * NODES, 0)
  leafval = Array.new(B * NODES, 0)

  state = 42
  B.times do |b|
    base = b * NODES
    LEAF_START.times do |node|
      state = (state * 1103515245 + 12345) & 0x7fffffff
      feat[base + node] = state % F
      state = (state * 1103515245 + 12345) & 0x7fffffff
      thr[base + node]  = state % 256
    end
    (LEAF_START...NODES).each do |node|
      state = (state * 1103515245 + 12345) & 0x7fffffff
      leafval[base + node] = state % 10
    end
  end

  sample = Array.new(n * F, 0)
  (n * F).times do |i|
    state = (state * 1103515245 + 12345) & 0x7fffffff
    sample[i] = state % 256
  end

  bands = (0...cores).map do |w|
    [w * n / cores, (w + 1) * n / cores]
  end

  # COMPUTE_NS region (to stderr): the parallel inference - fork+IPC of the B-tree
  # traversal over all samples, results returned in band order. Excludes the tree build
  # + sample data-gen above and the serial checksum below, so the scaling track's
  # speedup excludes interpreter startup + data-gen.
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  band_results = run_infer(cores, feat, thr, leafval, sample, bands)
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  $stderr.puts("COMPUTE_NS #{t1 - t0}")

  # Serial checksum over the acc values, in sample order - identical to serial gbdt.
  h     = 0
  total = 0
  band_results.each do |band_acc|
    band_acc.each do |acc|
      h     = (h * 31 + acc + 1) % P
      total = (total + acc)       % P
    end
  end
  [h, total]
end

cores = ARGV[0] ? ARGV[0].to_i : 1
n = ARGV[1] ? ARGV[1].to_i : 5000
h, total = gbdt_par(cores, n)
puts h
puts "gbdt(#{n}) = #{total}"
