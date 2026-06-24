// blur-par: parallel version of the blur benchmark.
// Decomposes each pass into `cores` row bands. Workers read the full input buffer
// (including neighbour rows for the 3x3 stencil — read-only, no contention) and
// write only their own output rows. After all workers complete a pass the buffers
// are swapped (same double-buffer scheme as serial) and the next pass begins.
// Border clamping: edge-replication, identical to the serial spec.
// Core-invariant: each output pixel depends only on a 3x3 region of the input;
// workers write disjoint output rows; result is bit-identical for any core count.
// Primitive: java.util.concurrent fixed-thread-pool.
// Invocation: blur-par <cores> <n>
import java.util.concurrent.{Callable, Executors}

object BlurPar {
  final val MOD: Long   = 1000000007L
  final val PASSES: Int = 4

  def lcg(s: Long): Long = (s * 1103515245L + 12345L) & 0x7fffffffL

  def clampi(x: Int, n: Int): Int = if (x < 0) 0 else if (x >= n) n - 1 else x

  def main(args: Array[String]): Unit = {
    val cores  = if (args.length >= 1) args(0).toInt else 1
    val n      = if (args.length >= 2) args(1).toInt else 256
    val warmup = sys.env.get("LL_WARMUP").flatMap(_.toIntOption).getOrElse(5)

    val k = Array(1, 2, 1, 2, 4, 2, 1, 2, 1) // 3x3 kernel, sum=16

    // LCG fill — identical seed and sequence as serial. Kept as the pristine input.
    val pristineSrc = new Array[Int](n * n)
    var s = 42L
    var idx = 0
    while (idx < n * n) { s = lcg(s); pristineSrc(idx) = (s % 256).toInt; idx += 1 }

    var src = new Array[Int](n * n)
    var dst = new Array[Int](n * n)

    val pool = Executors.newFixedThreadPool(cores)

    // Build per-worker row ranges once; reuse across passes and runs.
    val rowStart = new Array[Int](cores)
    val rowEnd   = new Array[Int](cores)
    var ww = 0
    while (ww < cores) {
      rowStart(ww) = ww * n / cores
      rowEnd(ww)   = (ww + 1) * n / cores
      ww += 1
    }

    // Run one full multi-pass blur compute starting from the current src/dst state.
    // Caller must restore src/dst before each call.
    def runCompute(): Unit = {
      var pass = 0
      while (pass < PASSES) {
        // Capture current src/dst references for this pass (mutable refs swap after join).
        val curSrc = src
        val curDst = dst

        val tasks = new java.util.ArrayList[Callable[Unit]]()
        var w = 0
        while (w < cores) {
          val wIndex = w
          val rStart = rowStart(wIndex)
          val rEnd   = rowEnd(wIndex)
          tasks.add(new Callable[Unit] {
            def call(): Unit = {
              var i = rStart
              while (i < rEnd) {
                var j = 0
                while (j < n) {
                  var acc = 0
                  var di = -1
                  while (di <= 1) {
                    val ni = clampi(i + di, n)
                    var dj = -1
                    while (dj <= 1) {
                      val nj = clampi(j + dj, n)
                      acc += k((di + 1) * 3 + (dj + 1)) * curSrc(ni * n + nj)
                      dj += 1
                    }
                    di += 1
                  }
                  curDst(i * n + j) = acc / 16
                  j += 1
                }
                i += 1
              }
            }
          })
          w += 1
        }
        // barrier: invokeAll blocks until all workers complete before the buffer swap.
        pool.invokeAll(tasks)

        // Double-buffer swap — same as serial (swap refs, not data).
        val t = src; src = dst; dst = t
        pass += 1
      }
    }

    // Reset src/dst to pristine state before each run (blur mutates src via double-buffer swap).
    def resetBuffers(): Unit = {
      System.arraycopy(pristineSrc, 0, src, 0, n * n)
      // dst is always fully overwritten before it's read; zeroing is not strictly required
      // but ensures a clean state for consistency.
      java.util.Arrays.fill(dst, 0)
    }

    // Warmup: run PASSES blur passes `warmup` times, discard results.
    var wi = 0
    while (wi < warmup) {
      resetBuffers()
      runCompute()
      wi += 1
    }

    // Timed run — restore pristine src before timing.
    resetBuffers()
    val t0 = System.nanoTime()
    runCompute()
    System.err.println("COMPUTE_NS " + (System.nanoTime() - t0))

    pool.shutdown()

    // Serial checksum over the final buffer (src after PASSES swaps).
    var h = 0L
    var p = 0
    while (p < n * n) { h = (h * 31 + src(p)) % MOD; p += 1 }

    println(h)
    println(s"blur($n)")
  }
}
