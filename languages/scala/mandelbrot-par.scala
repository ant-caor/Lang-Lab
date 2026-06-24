// mandelbrot-par: parallel version of the mandelbrot benchmark.
// Decomposes the N rows into `cores` contiguous bands (row-band decomposition).
// Each worker writes to a disjoint region of the output array; the final checksum
// (count of in-set pixels) is accumulated serially after all workers complete.
// Core-invariant: the per-pixel computation is purely a function of (x, y, n);
// no cross-pixel state, so the result is bit-identical for any core count.
// Primitive: java.util.concurrent fixed-thread-pool (no external libraries).
// Invocation: mandelbrot-par <cores> <n>
import java.util.concurrent.{Callable, Executors}

object MandelbrotPar {

  // Same pixel computation as the serial benchmark — FMA-proof t+t formula.
  def pixelInSet(x: Int, y: Int, n: Int): Boolean = {
    val cr = 2.0 * x / n - 1.5
    val ci = 2.0 * y / n - 1.0
    var zr = 0.0
    var zi = 0.0
    var tr = 0.0
    var ti = 0.0
    var i  = 0
    while (i < 50 && tr + ti <= 4.0) {
      val t = zr * zi
      zi = t + t + ci
      zr = tr - ti + cr
      tr = zr * zr
      ti = zi * zi
      i += 1
    }
    tr + ti <= 4.0
  }

  def main(args: Array[String]): Unit = {
    val cores  = if (args.length >= 1) args(0).toInt else 1
    val n      = if (args.length >= 2) args(1).toInt else 128
    val warmup = sys.env.get("LL_WARMUP").flatMap(_.toIntOption).getOrElse(5)

    // One long per row storing the count of in-set pixels in that row.
    val rowCounts = new Array[Long](n)

    val pool = Executors.newFixedThreadPool(cores)

    // Build per-worker row ranges once; reuse across warmup + timed runs.
    val rowStartArr = new Array[Int](cores)
    val rowEndArr   = new Array[Int](cores)
    var ww = 0
    while (ww < cores) {
      rowStartArr(ww) = ww * n / cores
      rowEndArr(ww)   = (ww + 1) * n / cores
      ww += 1
    }

    // Helper: build and run one full parallel compute pass.
    // rowCounts is fully overwritten by each pass (no prior state bleeds in).
    def runCompute(): Unit = {
      val tasks = new java.util.ArrayList[Callable[Unit]]()
      var w = 0
      while (w < cores) {
        val ww       = w
        val rowStart = rowStartArr(ww)
        val rowEnd   = rowEndArr(ww)
        tasks.add(new Callable[Unit] {
          def call(): Unit = {
            var y = rowStart
            while (y < rowEnd) {
              var rowCount = 0L
              var x = 0
              while (x < n) {
                if (pixelInSet(x, y, n)) rowCount += 1
                x += 1
              }
              rowCounts(y) = rowCount
              y += 1
            }
          }
        })
        w += 1
      }
      pool.invokeAll(tasks)
    }

    // Warmup: run the parallel compute region `warmup` times, discard results.
    // rowCounts is fully overwritten each pass, so no reset required between runs.
    var wi = 0
    while (wi < warmup) { runCompute(); wi += 1 }

    // Timed run.
    val t0 = System.nanoTime()
    runCompute()
    System.err.println("COMPUTE_NS " + (System.nanoTime() - t0))

    pool.shutdown()

    // Serial reduction — row-major order, same as serial benchmark.
    var count = 0L
    var y = 0
    while (y < n) { count += rowCounts(y); y += 1 }

    println(count)
    println(s"mandelbrot($n)")
  }
}
