// mandelbrot-par: parallel scaling-track variant. Invocation: <prog> <cores> <n>.
// Decomposes the NxN grid into `cores` horizontal row bands. Each worker counts
// in-set pixels for its band independently; results are summed serially after join.
// Core-invariant: each pixel computation is independent; per-band counts are
// summed in worker-index order (deterministic). Output matches serial spec.json.
// FMA-contraction-proof formula preserved: t+t instead of 2.0*zr*zi.
// JMH-style warmup: LL_WARMUP parallel compute runs (default 5) before the
// timed run so COMPUTE_NS reflects JIT-warmed steady state.

import java.util.concurrent.Executors
import java.util.concurrent.Callable

fun mandelbrotBand(n: Int, rowStart: Int, rowEnd: Int): Long {
    var count = 0L
    for (y in rowStart until rowEnd) {
        val ci = 2.0 * y / n - 1.0
        for (x in 0 until n) {
            val cr = 2.0 * x / n - 1.5
            var zr = 0.0
            var zi = 0.0
            var tr = 0.0
            var ti = 0.0
            var i = 0
            while (i < 50 && tr + ti <= 4.0) {
                val t = zr * zi
                zi = t + t + ci   // == 2*zr*zi + ci, FMA-proof
                zr = tr - ti + cr
                tr = zr * zr
                ti = zi * zi
                i++
            }
            if (tr + ti <= 4.0) count++
        }
    }
    return count
}

fun main(args: Array<String>) {
    val cores  = if (args.size >= 1) args[0].toInt() else 1
    val n      = if (args.size >= 2) args[1].toInt() else 128
    val warmup = System.getenv("LL_WARMUP")?.toIntOrNull() ?: 5

    // Data generation: inputs are purely derived from (cores, n) — no mutable state.
    // Build the band ranges once; they never change.
    val bands = (0 until cores).map { w ->
        Pair(w * n / cores, (w + 1) * n / cores)
    }

    val pool = Executors.newFixedThreadPool(cores)

    // Warmup: run the parallel compute region `warmup` times, discard results.
    // mandelbrot has no mutable output buffer — each run is a pure reduction.
    // No state to reset between warmup runs.
    repeat(warmup) {
        val tasks = bands.map { (rowStart, rowEnd) ->
            Callable<Long> { mandelbrotBand(n, rowStart, rowEnd) }
        }
        val futures = pool.invokeAll(tasks)
        for (f in futures) f.get()  // wait for completion, discard count
    }

    // Timed run: same compute region, result used for checksum + COMPUTE_NS.
    val tasks = bands.map { (rowStart, rowEnd) ->
        Callable<Long> { mandelbrotBand(n, rowStart, rowEnd) }
    }
    val t0 = System.nanoTime()
    val futures = pool.invokeAll(tasks)
    var count = 0L
    for (f in futures) count += f.get()
    System.err.println("COMPUTE_NS " + (System.nanoTime() - t0))
    pool.shutdown()

    println(count)
    println("mandelbrot($n)")
}
