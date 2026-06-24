// gemm-par: parallel scaling-track variant. Invocation: <prog> <cores> <n>.
// Row-band decomposition: worker w computes rows [w*N/cores, (w+1)*N/cores).
// A and B are read-only and shared across workers. C rows are disjoint — no
// shared-write contention. Checksum computed serially after all tasks join,
// identical to serial gemm.kt. Core-invariant: each C[i*N+j] = sum(A[i*N+k]*
// B[k*N+j], k=0..N-1) is independent of core count. Loop order i->k->j pinned.
// JMH-style warmup: LL_WARMUP parallel compute runs (default 5) before the
// timed run so COMPUTE_NS reflects JIT-warmed steady state. C is re-zeroed
// before each warmup run to prevent accumulation across iterations.

import java.util.concurrent.Executors
import java.util.concurrent.Callable

private const val GEMM_P = 1000000007L

private fun lcgGemm(s: Long): Long = (s * 1103515245L + 12345L) and 0x7fffffffL

private fun gemmBand(A: LongArray, B: LongArray, C: LongArray, n: Int, rowStart: Int, rowEnd: Int) {
    for (i in rowStart until rowEnd) {
        val base = i * n
        for (k in 0 until n) {
            val a = A[base + k]
            val kn = k * n
            for (j in 0 until n) {
                C[base + j] += a * B[kn + j]
            }
        }
    }
}

fun main(args: Array<String>) {
    val cores  = if (args.size >= 1) args[0].toInt() else 1
    val n      = if (args.size >= 2) args[1].toInt() else 256
    val warmup = System.getenv("LL_WARMUP")?.toIntOrNull() ?: 5

    // Data generation: same LCG as serial gemm.kt, outside warmup and timed regions.
    val A = LongArray(n * n)
    val B = LongArray(n * n)
    val C = LongArray(n * n)  // shared output array; re-zeroed before each run

    var s = 42L
    for (i in 0 until n * n) { s = lcgGemm(s); A[i] = s % 128 }
    for (i in 0 until n * n) { s = lcgGemm(s); B[i] = s % 128 }

    // Band ranges: worker w owns rows [w*n/cores, (w+1)*n/cores).
    val bands = (0 until cores).map { w ->
        Pair(w * n / cores, (w + 1) * n / cores)
    }

    val pool = Executors.newFixedThreadPool(cores)

    // Warmup: re-zero C before each run so warmup iterations don't accumulate.
    repeat(warmup) {
        C.fill(0L)
        val tasks = bands.map { (rowStart, rowEnd) ->
            Callable<Unit> { gemmBand(A, B, C, n, rowStart, rowEnd) }
        }
        val futures = pool.invokeAll(tasks)
        for (f in futures) f.get()
    }

    // Timed run: re-zero C once more, then measure only the parallel matmul.
    C.fill(0L)
    val t0 = System.nanoTime()
    val tasks = bands.map { (rowStart, rowEnd) ->
        Callable<Unit> { gemmBand(A, B, C, n, rowStart, rowEnd) }
    }
    val futures = pool.invokeAll(tasks)
    for (f in futures) f.get()
    System.err.println("COMPUTE_NS " + (System.nanoTime() - t0))
    pool.shutdown()

    // Checksum: single-threaded serial pass over full C, identical to serial gemm.kt.
    var h = 0L
    for (i in 0 until n * n) h = (h * 31 + C[i] % GEMM_P) % GEMM_P
    val secondary = C[n * n - 1] % GEMM_P
    println(h)
    println("gemm($n) = $secondary")
}
