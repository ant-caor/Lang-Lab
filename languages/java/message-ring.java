// message-ring: lightweight-concurrency / message-passing overhead axis.
// Measures the per-handoff instruction cost of JVM virtual threads (Project Loom, JDK 21+).
// 32 virtual-thread workers in a ring, all multiplexed on a SINGLE carrier OS thread.
// Carrier pinned via jdk.virtualThreadScheduler.parallelism=1 (set before any virtual thread
// is spawned). Handoff via SynchronousQueue (zero-buffer rendezvous -- suspends sender until
// receiver takes, exactly like an unbuffered channel). Transform happens inside each worker.
// All integer, no float, no I/O inside the lap loop.

import java.util.concurrent.SynchronousQueue;

class MessageRing {
    static final int RING_WIDTH = 32;
    static final long SEED = 12345L;
    static final long MOD = 1_000_000_007L;
    static final long MULT = 1103515245L;
    static final long MASK32 = 0xFFFFFFFFL;

    public static void main(String[] args) throws InterruptedException {
        // Pin the virtual-thread carrier pool to 1 OS thread BEFORE spawning any virtual thread.
        // Without this, the JVM creates a ForkJoinPool with parallelism = available processors,
        // which can exceed the qemu insn plugin's MAX_CPUS=8 slot limit.
        System.setProperty("jdk.virtualThreadScheduler.parallelism", "1");
        System.setProperty("jdk.virtualThreadScheduler.maxPoolSize", "1");

        int n = args.length > 0 ? Integer.parseInt(args[0]) : 500;

        // RING_WIDTH + 1 channels: channels[i] is the input queue for worker i;
        // channels[RING_WIDTH] is the return channel from worker 31 back to main.
        // SynchronousQueue has zero internal buffer -- put() blocks until take() is called,
        // exactly modelling an unbuffered cooperative handoff.
        @SuppressWarnings("unchecked")
        SynchronousQueue<Long>[] channels = new SynchronousQueue[RING_WIDTH + 1];
        for (int i = 0; i <= RING_WIDTH; i++) channels[i] = new SynchronousQueue<>();

        // Spawn RING_WIDTH virtual threads once before the lap loop.
        // Workers run for all n laps then exit; no per-lap spawn cost.
        Thread[] workers = new Thread[RING_WIDTH];
        for (int id = 0; id < RING_WIDTH; id++) {
            final SynchronousQueue<Long> inbox = channels[id];
            final SynchronousQueue<Long> outbox = channels[id + 1];
            final long addend = id + 1L;
            final int laps = n;
            workers[id] = Thread.ofVirtual().start(() -> {
                try {
                    for (int lap = 0; lap < laps; lap++) {
                        long v = inbox.take();
                        // 32-bit unsigned LCG transform -- MUST happen inside the worker (not folded into main)
                        long v2 = (v * MULT + addend) & MASK32;
                        outbox.put(v2);
                    }
                } catch (InterruptedException e) {
                    throw new RuntimeException(e);
                }
            });
        }

        // Main lap loop: push token into worker 0, receive transformed token back from worker 31.
        long v = SEED;
        SynchronousQueue<Long> toRing = channels[0];        // main  -> worker 0
        SynchronousQueue<Long> fromRing = channels[RING_WIDTH];   // worker 31 -> main
        for (int lap = 0; lap < n; lap++) {
            toRing.put(v);
            v = fromRing.take();
        }

        // Wait for all workers to finish.
        for (Thread w : workers) w.join();

        // Report OS thread count to stderr for MAX_CPUS=8 verification (not part of stdout output).
        int osThreads = Thread.getAllStackTraces().size();
        System.err.println("OS threads observed: " + osThreads);

        System.out.println(v % MOD);
        System.out.println((long) n * RING_WIDTH);
    }
}
