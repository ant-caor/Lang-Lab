# message-ring: the lightweight-concurrency / message-passing overhead axis. A ring of
# RING_WIDTH cooperative fibers threads a 32-bit token through every worker, n full laps,
# isolating the per-handoff instruction cost of MRI's cooperative concurrency primitive.
#
# Primitive: Fiber (MRI cooperative fibers). Fibers are green/cooperative -- they do NOT
# spawn OS threads and run under the GVL, so the whole ring stays on one OS thread by
# construction. Each Fiber.yield/resume IS the cooperative context switch being measured.
# The per-hop transform happens inside the worker fiber (never folded into main), and the
# 32 fibers are created once before the lap loop.
#
# Ruby ints are arbitrary precision, so the 32-bit unsigned wrap is done with `& MASK`.

RING_WIDTH = 32
SEED       = 12345
MOD        = 1000000007
MASK       = 0xFFFFFFFF

def run(n)
  # Build the ring of 32 worker fibers once, before the lap loop. Each worker applies
  # v = (v*1103515245 + (id+1)) & 0xFFFFFFFF and yields the result back to its resumer.
  workers = (0...RING_WIDTH).map do |id|
    addend = id + 1
    Fiber.new do |v|
      loop do
        v = Fiber.yield((v * 1103515245 + addend) & MASK)
      end
    end
  end

  v = SEED
  n.times do
    # one lap: hand the token through worker 0, 1, ..., 31 in order
    workers.each { |w| v = w.resume(v) }
  end

  v
end

n = ARGV[0] ? ARGV[0].to_i : 2000
puts run(n) % MOD
puts n * RING_WIDTH
