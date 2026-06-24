// gbdt-par: parallel scaling-track variant. Invocation: <prog> <cores> <n>.
// Decomposes the N samples into `cores` bands. Each worker traverses all B trees
// for its samples and stores per-sample acc values in a shared output array
// (no write contention: each worker writes only its own sample range).
// The tree arrays (feat, thr, leafval) are read-only and shared across workers.
// Core-invariant: each sample's accumulator depends only on its own features
// and the static (read-only) tree arrays; the final checksum pass is serial
// over the acc array in index order, identical to the serial benchmark.
// JMH-style warmup: LL_WARMUP parallel compute runs (default 5) before the
// timed run so COMPUTE_NS reflects JIT-warmed steady state.

import java.util.concurrent.Executors
import java.util.concurrent.Callable

const val GBDT_P         = 1000000007L
const val GBDT_D         = 8
const val GBDT_B         = 200
const val GBDT_F         = 8
const val GBDT_NODES     = 511   // 2^(D+1) - 1
const val GBDT_LEAF_START = 255  // 2^D - 1

fun gbdtLcg(s: Long): Long = (s * 1103515245L + 12345L) and 0x7fffffffL

fun gbdtBand(
    sample: IntArray, feat: IntArray, thr: IntArray, leafval: IntArray,
    accArr: LongArray, n: Int, rowStart: Int, rowEnd: Int
) {
    for (i in rowStart until rowEnd) {
        val sbase = i * GBDT_F
        var acc   = 0L
        for (b in 0 until GBDT_B) {
            val tbase = b * GBDT_NODES
            var node  = 0
            repeat(GBDT_D) {
                node = if (sample[sbase + feat[tbase + node]] <= thr[tbase + node])
                    2 * node + 1
                else
                    2 * node + 2
            }
            acc += leafval[tbase + node].toLong()
        }
        accArr[i] = acc
    }
}

fun main(args: Array<String>) {
    val cores  = if (args.size >= 1) args[0].toInt() else 1
    val n      = if (args.size >= 2) args[1].toInt() else 5000
    val warmup = System.getenv("LL_WARMUP")?.toIntOrNull() ?: 5

    // Data generation (outside warmup and timed regions): generate once.
    val feat    = IntArray(GBDT_B * GBDT_NODES)
    val thr     = IntArray(GBDT_B * GBDT_NODES)
    val leafval = IntArray(GBDT_B * GBDT_NODES)

    var s = 42L
    for (b in 0 until GBDT_B) {
        val base = b * GBDT_NODES
        for (node in 0 until GBDT_LEAF_START) {
            s = gbdtLcg(s); feat[base + node] = (s % GBDT_F).toInt()
            s = gbdtLcg(s); thr [base + node] = (s % 256).toInt()
        }
        for (node in GBDT_LEAF_START until GBDT_NODES) {
            s = gbdtLcg(s); leafval[base + node] = (s % 10).toInt()
        }
    }

    val sample = IntArray(n * GBDT_F)
    for (i in 0 until n * GBDT_F) {
        s = gbdtLcg(s); sample[i] = (s % 256).toInt()
    }

    val accArr = LongArray(n)   // per-sample accumulator; written by disjoint workers

    val pool  = Executors.newFixedThreadPool(cores)
    val bands = (0 until cores).map { w -> Pair(w * n / cores, (w + 1) * n / cores) }

    // Warmup: zero accArr, submit tasks, wait. Inputs (sample/feat/thr/leafval) are
    // read-only so no reset needed for them; accArr is the only mutable output.
    repeat(warmup) {
        accArr.fill(0L)
        val tasks = bands.map { (rowStart, rowEnd) ->
            Callable<Unit> { gbdtBand(sample, feat, thr, leafval, accArr, n, rowStart, rowEnd) }
        }
        val futures = pool.invokeAll(tasks)
        for (f in futures) f.get()
        // accArr contents discarded; will be overwritten by timed run
    }

    // Timed run: zero accArr, then measure invokeAll + get.
    accArr.fill(0L)
    val tasks = bands.map { (rowStart, rowEnd) ->
        Callable<Unit> { gbdtBand(sample, feat, thr, leafval, accArr, n, rowStart, rowEnd) }
    }
    val t0 = System.nanoTime()
    val futures = pool.invokeAll(tasks)
    for (f in futures) f.get()
    System.err.println("COMPUTE_NS " + (System.nanoTime() - t0))
    pool.shutdown()

    // Serial checksum pass (same order as serial benchmark)
    var h     = 0L
    var total = 0L
    for (i in 0 until n) {
        val acc = accArr[i]
        h     = (h * 31 + acc + 1) % GBDT_P
        total = (total + acc) % GBDT_P
    }
    println(h)
    println("gbdt($n) = $total")
}
