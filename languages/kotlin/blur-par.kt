// blur-par: parallel scaling-track variant. Invocation: <prog> <cores> <n>.
// Decomposes each blur pass into `cores` horizontal row bands. Workers write
// only their output rows; a barrier (join) separates passes. Double-buffer
// swap is serial between passes. Clamp border handling identical to serial.
// Core-invariant: each output pixel depends only on its 3x3 neighbourhood in
// the INPUT buffer (read-only for all workers within a pass). Output is
// independent of the number of workers. Checksum computed serially after all passes.
// JMH-style warmup: LL_WARMUP parallel compute runs (default 5) before the
// timed run so COMPUTE_NS reflects JIT-warmed steady state.

import java.util.concurrent.Executors
import java.util.concurrent.Callable

const val PAR_P = 1000000007L
const val PAR_PASSES = 4

fun lcgPar(s: Long): Long = (s * 1103515245L + 12345L) and 0x7fffffffL
fun clampiPar(x: Int, n: Int): Int = if (x < 0) 0 else if (x >= n) n - 1 else x

fun blurBand(src: IntArray, dst: IntArray, n: Int, rowStart: Int, rowEnd: Int) {
    val k = intArrayOf(1, 2, 1, 2, 4, 2, 1, 2, 1)
    for (i in rowStart until rowEnd) {
        for (j in 0 until n) {
            var acc = 0
            for (di in -1..1) {
                val ni = clampiPar(i + di, n)
                for (dj in -1..1) {
                    val nj = clampiPar(j + dj, n)
                    acc += k[(di + 1) * 3 + (dj + 1)] * src[ni * n + nj]
                }
            }
            dst[i * n + j] = acc / 16
        }
    }
}

fun runBlurPasses(
    initialSrc: IntArray, buf0: IntArray, buf1: IntArray,
    n: Int, cores: Int,
    pool: java.util.concurrent.ExecutorService,
    bands: List<Pair<Int, Int>>
): IntArray {
    // Copy pristine input into buf0, use buf1 as dst.
    initialSrc.copyInto(buf0)
    var src = buf0
    var dst = buf1
    repeat(PAR_PASSES) {
        val srcFinal = src
        val dstFinal = dst
        val tasks = bands.map { (rowStart, rowEnd) ->
            Callable<Unit> { blurBand(srcFinal, dstFinal, n, rowStart, rowEnd) }
        }
        val futures = pool.invokeAll(tasks)
        for (f in futures) f.get()   // barrier: all workers done before swap
        val t = src; src = dst; dst = t
    }
    // After PAR_PASSES (4, even) swaps, src holds the final result.
    return src
}

fun main(args: Array<String>) {
    val cores  = if (args.size >= 1) args[0].toInt() else 1
    val n      = if (args.size >= 2) args[1].toInt() else 256
    val warmup = System.getenv("LL_WARMUP")?.toIntOrNull() ?: 5

    // Data generation (outside warmup and timed regions): generate once.
    val pristine = IntArray(n * n)
    var s = 42L
    for (idx in 0 until n * n) {
        s = lcgPar(s)
        pristine[idx] = (s % 256).toInt()
    }

    // Two reusable buffers for double-buffering across all runs.
    val buf0 = IntArray(n * n)
    val buf1 = IntArray(n * n)

    val bands = (0 until cores).map { w ->
        Pair(w * n / cores, (w + 1) * n / cores)
    }

    val pool = Executors.newFixedThreadPool(cores)

    // Warmup: restore pristine -> buf0 before each run so each run starts fresh.
    // Results (the returned src reference) are discarded.
    repeat(warmup) {
        runBlurPasses(pristine, buf0, buf1, n, cores, pool, bands)
    }

    // Timed run: restore pristine into buf0 once more, then time the passes.
    pristine.copyInto(buf0)
    var src = buf0
    var dst = buf1
    val t0 = System.nanoTime()
    repeat(PAR_PASSES) {
        val srcFinal = src
        val dstFinal = dst
        val tasks = bands.map { (rowStart, rowEnd) ->
            Callable<Unit> { blurBand(srcFinal, dstFinal, n, rowStart, rowEnd) }
        }
        val futures = pool.invokeAll(tasks)
        for (f in futures) f.get()
        val t = src; src = dst; dst = t
    }
    System.err.println("COMPUTE_NS " + (System.nanoTime() - t0))
    pool.shutdown()

    var h = 0L
    for (idx in 0 until n * n) {
        h = (h * 31 + src[idx]) % PAR_P
    }
    println(h)
    println("blur($n)")
}
