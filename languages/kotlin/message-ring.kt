// message-ring: lightweight-concurrency / message-passing overhead axis.
// Measures the per-handoff instruction cost of JVM virtual threads (Project Loom, JDK 21+).
// 32 virtual-thread workers in a ring, all multiplexed on a SINGLE carrier OS thread.
// Carrier pinned via jdk.virtualThreadScheduler.parallelism=1 (set before any virtual thread
// is spawned). Handoff via SynchronousQueue (zero-buffer rendezvous -- suspends sender until
// receiver takes, exactly like an unbuffered channel). Transform happens inside each worker.
// All integer, no float, no I/O inside the lap loop.

import java.util.concurrent.SynchronousQueue

const val RING_WIDTH = 32
const val SEED       = 12345L
const val MOD        = 1_000_000_007L
const val MULT       = 1103515245L
const val MASK32     = 0xFFFFFFFFL

fun main(args: Array<String>) {
    // Pin the virtual-thread carrier pool to 1 OS thread BEFORE spawning any virtual thread.
    // Without this, the JVM creates a ForkJoinPool with parallelism = available processors,
    // which can exceed the qemu insn plugin's MAX_CPUS=8 slot limit.
    System.setProperty("jdk.virtualThreadScheduler.parallelism", "1")
    System.setProperty("jdk.virtualThreadScheduler.maxPoolSize", "1")

    val n = if (args.isNotEmpty()) args[0].toInt() else 500

    // RING_WIDTH + 1 channels: channels[i] is the input queue for worker i;
    // channels[RING_WIDTH] is the return channel from worker 31 back to main.
    // SynchronousQueue has zero internal buffer -- put() blocks until take() is called,
    // exactly modelling an unbuffered cooperative handoff.
    val channels = Array(RING_WIDTH + 1) { SynchronousQueue<Long>() }

    // Spawn RING_WIDTH virtual threads once before the lap loop.
    // Workers run for all n laps then exit; no per-lap spawn cost.
    val workers = Array(RING_WIDTH) { id ->
        val inbox  = channels[id]
        val outbox = channels[id + 1]
        val addend = (id + 1).toLong()
        Thread.ofVirtual().start {
            repeat(n) {
                val v = inbox.take()
                // 32-bit unsigned LCG transform -- MUST happen inside the worker (not folded into main)
                val v2 = (v * MULT + addend) and MASK32
                outbox.put(v2)
            }
        }
    }

    // Main lap loop: push token into worker 0, receive transformed token back from worker 31.
    var v = SEED
    val toRing   = channels[0]           // main  -> worker 0
    val fromRing = channels[RING_WIDTH]  // worker 31 -> main
    repeat(n) {
        toRing.put(v)
        v = fromRing.take()
    }

    // Wait for all workers to finish.
    for (w in workers) w.join()

    // Report OS thread count to stderr for MAX_CPUS=8 verification (not part of stdout output).
    val osThreads = Thread.getAllStackTraces().size
    System.err.println("OS threads observed: $osThreads")

    println(v % MOD)
    println(n * RING_WIDTH)
}
