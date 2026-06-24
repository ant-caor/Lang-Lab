// k-means-par: parallel version of the k-means benchmark.
// Parallelizes ONLY the assignment step: divide the N points into `cores` bands;
// each worker computes the nearest centroid (strict < lowest-index tie-break) for its
// points and accumulates partial per-cluster sums + counts.
// After all workers complete, the main thread merges the partial accumulators and
// performs the centroid update serially (floor-mean, empty cluster unchanged) —
// exactly as the serial benchmark.
// The final assignment pass (after the last iteration) is also parallelized the same way.
// Core-invariant: each point's assignment depends only on the current centroids and that
// point's coordinates; the strict-< tie-break is preserved because each worker scans its
// own points in the same order as the serial code. Centroids are updated serially, so the
// centroid sequence is identical for any core count.
// Primitive: java.util.concurrent fixed-thread-pool.
// Invocation: k-means-par <cores> <n>
import java.util.concurrent.{Callable, Executors}

object KMeansPar {
  final val MOD: Long   = 1000000007L
  final val K: Int      = 16
  final val D: Int      = 4
  final val ITERS: Int  = 10
  final val RANGE: Long = 256L

  def lcgNext(s: Long): Long = (s * 1103515245L + 12345L) & 0x7fffffffL

  def main(args: Array[String]): Unit = {
    val cores  = if (args.length >= 1) args(0).toInt else 1
    val n      = if (args.length >= 2) args(1).toInt else 8000
    val warmup = sys.env.get("LL_WARMUP").flatMap(_.toIntOption).getOrElse(5)

    // 1. Generate N integer D-dimensional points — identical LCG sequence as serial.
    val pt = new Array[Long](n * D)
    var state = 42L
    var i = 0
    while (i < n * D) { state = lcgNext(state); pt(i) = state % RANGE; i += 1 }

    // Initial centroids snapshot = first K points — identical to serial.
    // Saved once; restored before each run to guarantee identical centroid sequence.
    val initCen = new Array[Long](K * D)
    i = 0
    while (i < K * D) { initCen(i) = pt(i); i += 1 }

    // Working centroid and assignment arrays — mutated during compute.
    val cen    = new Array[Long](K * D)
    val assign = new Array[Int](n)

    // Per-worker partial accumulators: ssum[w][k*D+d], cnt[w][k].
    val partSsum = Array.ofDim[Long](cores, K * D)
    val partCnt  = Array.ofDim[Long](cores, K)

    // Serial aggregates reused across iterations.
    val ssum = new Array[Long](K * D)
    val cnt  = new Array[Long](K)

    val pool = Executors.newFixedThreadPool(cores)

    // Compute point-band boundaries once.
    val ptStart = new Array[Int](cores)
    val ptEnd   = new Array[Int](cores)
    var ww = 0
    while (ww < cores) {
      ptStart(ww) = ww * n / cores
      ptEnd(ww)   = (ww + 1) * n / cores
      ww += 1
    }

    // Helper: run a parallel assignment step. Workers also accumulate partial sums+counts
    // when `accumulate` is true (used for iterations 0..ITERS-1; false for the final pass).
    def runAssignment(accumulate: Boolean): Unit = {
      val tasks = new java.util.ArrayList[Callable[Unit]]()
      var w = 0
      while (w < cores) {
        val wIndex = w
        val pStart = ptStart(wIndex)
        val pEnd   = ptEnd(wIndex)
        tasks.add(new Callable[Unit] {
          def call(): Unit = {
            // Reset this worker's partial accumulators if accumulating.
            if (accumulate) {
              var kd = 0; while (kd < K * D) { partSsum(wIndex)(kd) = 0L; kd += 1 }
              var kk = 0; while (kk < K) { partCnt(wIndex)(kk) = 0L; kk += 1 }
            }
            var ii = pStart
            while (ii < pEnd) {
              var best = 0
              var bd   = -1L
              var kk   = 0
              while (kk < K) {
                var dist = 0L
                var d    = 0
                while (d < D) {
                  val df = pt(ii * D + d) - cen(kk * D + d)
                  dist += df * df
                  d += 1
                }
                if (bd < 0 || dist < bd) { bd = dist; best = kk }
                kk += 1
              }
              assign(ii) = best
              if (accumulate) {
                partCnt(wIndex)(best) += 1
                var d = 0
                while (d < D) { partSsum(wIndex)(best * D + d) += pt(ii * D + d); d += 1 }
              }
              ii += 1
            }
          }
        })
        w += 1
      }
      pool.invokeAll(tasks)
    }

    // Restore mutable state to initial conditions before each run.
    // pt is read-only (never mutated), so no restore needed for it.
    def resetState(): Unit = {
      System.arraycopy(initCen, 0, cen, 0, K * D)
      // assign is fully overwritten during the run; no reset needed.
    }

    // Run one full k-means compute: ITERS parallel-assign + serial-update + final assignment.
    def runCompute(): Unit = {
      var iter = 0
      while (iter < ITERS) {
        runAssignment(accumulate = true)

        // Merge partial accumulators serially.
        var kd = 0; while (kd < K * D) { ssum(kd) = 0L; kd += 1 }
        var kk = 0; while (kk < K) { cnt(kk) = 0L; kk += 1 }
        var w = 0
        while (w < cores) {
          kd = 0; while (kd < K * D) { ssum(kd) += partSsum(w)(kd); kd += 1 }
          kk = 0; while (kk < K) { cnt(kk) += partCnt(w)(kk); kk += 1 }
          w += 1
        }

        // Serial centroid update — floor-mean, empty cluster unchanged.
        kk = 0
        while (kk < K) {
          if (cnt(kk) > 0) {
            var d = 0
            while (d < D) { cen(kk * D + d) = ssum(kk * D + d) / cnt(kk); d += 1 }
          }
          kk += 1
        }

        iter += 1
      }

      // Final assignment pass with the final centroids (no accumulation needed).
      runAssignment(accumulate = false)
    }

    // Warmup: run full k-means compute `warmup` times, discard results.
    var wi = 0
    while (wi < warmup) {
      resetState()
      runCompute()
      wi += 1
    }

    // Timed run — restore state before timing.
    resetState()
    val t0 = System.nanoTime()
    runCompute()
    System.err.println("COMPUTE_NS " + (System.nanoTime() - t0))

    pool.shutdown()

    // Checksum: hash the final centroids, then every point's assignment.
    var h = 0L
    i = 0
    while (i < K * D) { h = (h * 31 + cen(i)) % MOD; i += 1 }
    i = 0
    while (i < n) { h = (h * 31 + assign(i)) % MOD; i += 1 }

    println(h)
    println(s"k-means($n)")
  }
}
