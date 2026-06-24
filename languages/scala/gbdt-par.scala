// gbdt-par: parallel version of the gbdt benchmark.
// Divides the N samples into `cores` contiguous bands. Each worker traverses all B
// trees for its samples — the tree arrays (feat, thr, leafval) are static and
// read-only, so concurrent reads are safe with no synchronisation.
// Per-sample accumulators (acc[i]) are written only by the owning worker.
// The final checksum/secondary pass runs serially over all samples in index order,
// identical to the serial benchmark.
// Core-invariant: each sample's result depends only on the static trees and that
// sample's feature values; the index-order checksum pass is deterministic for any
// core count.
// Primitive: java.util.concurrent fixed-thread-pool.
// Invocation: gbdt-par <cores> <n>
import java.util.concurrent.{Callable, Executors}

object GbdtPar {
  final val MOD: Long       = 1000000007L
  final val DEPTH: Int      = 8
  final val BTREES: Int     = 200
  final val FEATURES: Int   = 8
  final val NODES: Int      = 511   // 2^(D+1) - 1
  final val LEAF_START: Int = 255   // 2^D - 1

  def lcg(s: Long): Long = (s * 1103515245L + 12345L) & 0x7fffffffL

  def main(args: Array[String]): Unit = {
    val cores  = if (args.length >= 1) args(0).toInt else 1
    val n      = if (args.length >= 2) args(1).toInt else 5000
    val warmup = sys.env.get("LL_WARMUP").flatMap(_.toIntOption).getOrElse(5)

    // Build tree arrays — same LCG sequence as serial.
    val feat    = new Array[Int](BTREES * NODES)
    val thr     = new Array[Int](BTREES * NODES)
    val leafval = new Array[Int](BTREES * NODES)

    var s = 42L
    var b = 0
    while (b < BTREES) {
      val base = b * NODES
      var node = 0
      while (node < LEAF_START) {
        s = lcg(s); feat(base + node) = (s % FEATURES).toInt
        s = lcg(s); thr (base + node) = (s % 256).toInt
        node += 1
      }
      node = LEAF_START
      while (node < NODES) {
        s = lcg(s); leafval(base + node) = (s % 10).toInt
        node += 1
      }
      b += 1
    }

    // Generate samples — same LCG continuation as serial.
    val sample = new Array[Int](n * FEATURES)
    var i = 0
    while (i < n * FEATURES) { s = lcg(s); sample(i) = (s % 256).toInt; i += 1 }

    // Per-sample accumulator written by workers, read by the serial checksum pass.
    // feat, thr, leafval, sample are all read-only after data-gen — no restore needed.
    val acc = new Array[Long](n)

    val pool = Executors.newFixedThreadPool(cores)

    // Helper: build and run one full parallel GBDT inference pass.
    // acc is fully overwritten by each pass (every element written by exactly one worker).
    def runCompute(): Unit = {
      val tasks = new java.util.ArrayList[Callable[Unit]]()
      var w = 0
      while (w < cores) {
        val ww     = w
        val sStart = ww * n / cores
        val sEnd   = (ww + 1) * n / cores
        tasks.add(new Callable[Unit] {
          def call(): Unit = {
            var ii = sStart
            while (ii < sEnd) {
              val sbase = ii * FEATURES
              var a     = 0L
              var bb    = 0
              while (bb < BTREES) {
                val tbase = bb * NODES
                var node  = 0
                var d     = 0
                while (d < DEPTH) {
                  node = if (sample(sbase + feat(tbase + node)) <= thr(tbase + node))
                    2 * node + 1
                  else
                    2 * node + 2
                  d += 1
                }
                a += leafval(tbase + node).toLong
                bb += 1
              }
              acc(ii) = a
              ii += 1
            }
          }
        })
        w += 1
      }
      pool.invokeAll(tasks)
    }

    // Warmup: run GBDT inference `warmup` times, discard results.
    // acc is fully overwritten each pass, feat/thr/leafval/sample are read-only — no reset needed.
    var wi = 0
    while (wi < warmup) { runCompute(); wi += 1 }

    // Timed run.
    val t0 = System.nanoTime()
    runCompute()
    System.err.println("COMPUTE_NS " + (System.nanoTime() - t0))

    pool.shutdown()

    // Serial checksum — same order and formula as serial benchmark.
    var h     = 0L
    var total = 0L
    i = 0
    while (i < n) {
      h     = (h * 31 + acc(i) + 1) % MOD
      total = (total + acc(i)) % MOD
      i += 1
    }

    println(h)
    println(s"gbdt($n) = $total")
  }
}
