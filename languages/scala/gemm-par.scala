// gemm-par: parallel version of the quantized integer matrix-multiply benchmark.
// Decomposes the N output rows of C into `cores` contiguous row bands.
// Each worker computes C rows [w*N/cores, (w+1)*N/cores) with the pinned i,k,j
// loop order — identical to the serial gemm inner loop. A and B are read-only
// and shared across all workers. Workers write disjoint rows of C, so there is
// no shared-write contention on the compute path.
// Core-invariant: C[i*N+j] = sum_k A[i*N+k]*B[k*N+j], independent of which
// worker computed it, so the final C array is bit-identical for any core count.
// Checksum computed serially after all tasks join, same order as serial gemm.
// Primitive: java.util.concurrent fixed-thread-pool sized to `cores`. No Akka.
// Invocation: gemm-par <cores> <n>
import java.util.concurrent.{Callable, Executors}

object GemmPar {
  final val P = 1000000007L

  def lcgNext(s: Long): Long = (s * 1103515245L + 12345L) & 0x7fffffffL

  def main(args: Array[String]): Unit = {
    val cores  = if (args.length >= 1) args(0).toInt else 1
    val n      = if (args.length >= 2) args(1).toInt else 256
    val warmup = sys.env.get("LL_WARMUP").flatMap(_.toIntOption).getOrElse(5)

    // Generate A and B exactly as serial gemm (same LCG seed, same order).
    // A and B are read-only during compute; allocated once and reused across all runs.
    val A = new Array[Long](n * n)
    val B = new Array[Long](n * n)

    var state = 42L
    var idx = 0
    while (idx < n * n) { state = lcgNext(state); A(idx) = state % 128; idx += 1 }
    idx = 0
    while (idx < n * n) { state = lcgNext(state); B(idx) = state % 128; idx += 1 }

    // C is zero-initialized before each compute run.
    // Allocate once; reset to zero before each warmup/timed run.
    val C = new Array[Long](n * n)

    val pool = Executors.newFixedThreadPool(cores)

    // Build per-worker row ranges once; reused across warmup + timed runs.
    val rowStart = new Array[Int](cores)
    val rowEnd   = new Array[Int](cores)
    var ww = 0
    while (ww < cores) {
      rowStart(ww) = ww * n / cores
      rowEnd(ww)   = (ww + 1) * n / cores
      ww += 1
    }

    // Run one full parallel matmul. C must be zeroed by the caller before each call
    // so that warmup re-runs don't double-accumulate.
    def runCompute(): Unit = {
      val tasks = new java.util.ArrayList[Callable[Unit]]()
      var w = 0
      while (w < cores) {
        val wIdx   = w
        val rStart = rowStart(wIdx)
        val rEnd   = rowEnd(wIdx)
        tasks.add(new Callable[Unit] {
          def call(): Unit = {
            // Pinned loop order i -> k -> j, restricted to this worker's row band.
            var i = rStart
            while (i < rEnd) {
              val base = i * n
              var k = 0
              while (k < n) {
                val a  = A(base + k)
                val kn = k * n
                var j  = 0
                while (j < n) {
                  C(base + j) += a * B(kn + j)
                  j += 1
                }
                k += 1
              }
              i += 1
            }
          }
        })
        w += 1
      }
      // invokeAll blocks until all workers complete — provides the full barrier before
      // the buffer-swap / checksum pass, identical to how blur-par uses it.
      pool.invokeAll(tasks)
    }

    // Warmup: run the full parallel matmul `warmup` times, discarding results.
    // C must be re-zeroed before each run so accumulations don't bleed across iterations.
    var wi = 0
    while (wi < warmup) {
      java.util.Arrays.fill(C, 0L)
      runCompute()
      wi += 1
    }

    // Timed run — zero C, then measure only the parallel compute region.
    java.util.Arrays.fill(C, 0L)
    val t0 = System.nanoTime()
    runCompute()
    System.err.println("COMPUTE_NS " + (System.nanoTime() - t0))

    pool.shutdown()

    // Serial checksum over full C row-major — identical to serial gemm.
    var h = 0L
    var i = 0
    while (i < n * n) { h = (h * 31 + C(i) % P) % P; i += 1 }
    val secondary = C(n * n - 1) % P

    println(h)
    println(s"gemm($n) = $secondary")
  }
}
