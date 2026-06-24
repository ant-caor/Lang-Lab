// k-means-par: parallel scaling-track variant. Invocation: <prog> <cores> <n>.
// Parallelizes the ASSIGNMENT step: points are divided into `cores` bands;
// each worker computes nearest centroid (strict < tie-break, lowest-index wins)
// for its points and accumulates partial sums+counts. The CENTROID UPDATE is
// serial: the main thread merges all partial sums/counts then computes floor-means.
// Core-invariant: each point's assignment depends only on the (read-only) centroids
// and its own coordinates; the order within a worker's band is identical to the
// serial scan order; partials are merged in worker-index order. Final assignment
// is recomputed serially with the final centroids (same as serial benchmark).
// JMH-style warmup: LL_WARMUP parallel compute runs (default 5) before the
// timed run so COMPUTE_NS reflects JIT-warmed steady state.

import java.util.concurrent.Executors
import java.util.concurrent.Callable

const val KM_P     = 1000000007L
const val KM_K     = 16
const val KM_D     = 4
const val KM_ITERS = 10
const val KM_RANGE = 256L

fun assignBand(
    pt: LongArray, cen: LongArray, assign: IntArray,
    n: Int, rowStart: Int, rowEnd: Int,
    ssum: LongArray, cnt: LongArray
) {
    // Clear partials for this worker
    for (i in ssum.indices) ssum[i] = 0L
    for (i in cnt.indices)  cnt[i]  = 0L
    for (i in rowStart until rowEnd) {
        var best = 0
        var bd = -1L
        for (k in 0 until KM_K) {
            var dist = 0L
            for (d in 0 until KM_D) {
                val df = pt[i * KM_D + d] - cen[k * KM_D + d]
                dist += df * df
            }
            if (bd < 0 || dist < bd) { bd = dist; best = k }
        }
        assign[i] = best
        cnt[best]++
        for (d in 0 until KM_D) ssum[best * KM_D + d] += pt[i * KM_D + d]
    }
}

fun runKMeans(
    pt: LongArray, cen: LongArray, assign: IntArray,
    initCen: LongArray,
    n: Int, cores: Int,
    pool: java.util.concurrent.ExecutorService,
    bands: List<Pair<Int, Int>>,
    wSsum: Array<LongArray>, wCnt: Array<LongArray>
) {
    // Reset mutable state: restore centroids to first-K-points initialisation,
    // zero assign array (not strictly required but safe).
    initCen.copyInto(cen)
    assign.fill(0)

    for (iter in 0 until KM_ITERS) {
        // Parallel assignment
        val tasks = bands.mapIndexed { w, (rowStart, rowEnd) ->
            Callable<Unit> {
                assignBand(pt, cen, assign, n, rowStart, rowEnd, wSsum[w], wCnt[w])
            }
        }
        val futures = pool.invokeAll(tasks)
        for (f in futures) f.get()

        // Serial centroid update: merge partials, floor-mean, empty unchanged
        val ssum = LongArray(KM_K * KM_D)
        val cnt  = LongArray(KM_K)
        for (w in 0 until cores) {
            for (i in 0 until KM_K * KM_D) ssum[i] += wSsum[w][i]
            for (k in 0 until KM_K)        cnt[k]  += wCnt[w][k]
        }
        for (k in 0 until KM_K) {
            if (cnt[k] > 0) {
                for (d in 0 until KM_D) cen[k * KM_D + d] = ssum[k * KM_D + d] / cnt[k]
            }
        }
    }
}

fun main(args: Array<String>) {
    val cores  = if (args.size >= 1) args[0].toInt() else 1
    val n      = if (args.size >= 2) args[1].toInt() else 8000
    val warmup = System.getenv("LL_WARMUP")?.toIntOrNull() ?: 5

    // Data generation (outside warmup and timed regions): generate once.
    val pt = LongArray(n * KM_D)
    var s = 42L
    for (i in 0 until n * KM_D) {
        s = (s * 1103515245L + 12345L) and 0x7fffffffL
        pt[i] = s % KM_RANGE
    }
    // Pristine initial centroids: first KM_K points of pt.
    val initCen = LongArray(KM_K * KM_D) { pt[it] }

    val cen    = LongArray(KM_K * KM_D)
    val assign = IntArray(n)

    val pool  = Executors.newFixedThreadPool(cores)
    val bands = (0 until cores).map { w -> Pair(w * n / cores, (w + 1) * n / cores) }

    // Per-worker partial accumulator arrays (allocated once, reused across all runs).
    val wSsum = Array(cores) { LongArray(KM_K * KM_D) }
    val wCnt  = Array(cores) { LongArray(KM_K) }

    // Warmup: each call resets cen+assign internally before running KM_ITERS iterations.
    repeat(warmup) {
        runKMeans(pt, cen, assign, initCen, n, cores, pool, bands, wSsum, wCnt)
        // cen and assign after this call are discarded (overwritten before timed run)
    }

    // Timed run: reset then measure.
    initCen.copyInto(cen)
    assign.fill(0)
    val t0 = System.nanoTime()
    for (iter in 0 until KM_ITERS) {
        val tasks = bands.mapIndexed { w, (rowStart, rowEnd) ->
            Callable<Unit> {
                assignBand(pt, cen, assign, n, rowStart, rowEnd, wSsum[w], wCnt[w])
            }
        }
        val futures = pool.invokeAll(tasks)
        for (f in futures) f.get()

        val ssum = LongArray(KM_K * KM_D)
        val cnt  = LongArray(KM_K)
        for (w in 0 until cores) {
            for (i in 0 until KM_K * KM_D) ssum[i] += wSsum[w][i]
            for (k in 0 until KM_K)        cnt[k]  += wCnt[w][k]
        }
        for (k in 0 until KM_K) {
            if (cnt[k] > 0) {
                for (d in 0 until KM_D) cen[k * KM_D + d] = ssum[k * KM_D + d] / cnt[k]
            }
        }
    }
    System.err.println("COMPUTE_NS " + (System.nanoTime() - t0))
    pool.shutdown()

    // Final assignment with final centroids (serial, same as serial benchmark).
    for (i in 0 until n) {
        var best = 0
        var bd = -1L
        for (k in 0 until KM_K) {
            var dist = 0L
            for (d in 0 until KM_D) {
                val df = pt[i * KM_D + d] - cen[k * KM_D + d]
                dist += df * df
            }
            if (bd < 0 || dist < bd) { bd = dist; best = k }
        }
        assign[i] = best
    }

    var h = 0L
    for (i in 0 until KM_K * KM_D) h = (h * 31 + cen[i]) % KM_P
    for (i in 0 until n) h = (h * 31 + assign[i]) % KM_P
    println(h)
    println("k-means($n)")
}
