// gbdt: gradient-boosted decision-tree ensemble inference — the dominant tabular-ML
// algorithm (XGBoost/LightGBM/CatBoost style). B=200 trees of depth D=8 over F=8
// features. Each tree is a flat complete binary tree (NODES=511): internal nodes
// 0..254 store a (feature-index, threshold) split; leaves 255..510 store a value.
// Children of node k: left=2k+1, right=2k+2. Inference: for each sample, traverse
// all B trees (exactly D compare-and-branch steps each) and sum the leaf values.
// Checksum: poly-hash of (acc+1) per sample; secondary = sum of acc values mod P.
// LCG draw order pinned: feat then thr per internal node, leafval per leaf, samples.
// All integer — no float, no ML/tree library.
object Gbdt {
  final val P: Long = 1000000007L
  final val D: Int  = 8
  final val B: Int  = 200
  final val F: Int  = 8
  final val NODES: Int      = 511  // 2^(D+1) - 1
  final val LEAF_START: Int = 255  // 2^D - 1

  def lcg(s: Long): Long = (s * 1103515245L + 12345L) & 0x7fffffffL

  def run(n: Int): (Long, Long) = {
    val feat    = new Array[Int](B * NODES)
    val thr     = new Array[Int](B * NODES)
    val leafval = new Array[Int](B * NODES)

    var s = 42L
    var b = 0
    while (b < B) {
      val base = b * NODES
      var node = 0
      while (node < LEAF_START) {
        s = lcg(s); feat(base + node) = (s % F).toInt
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

    val sample = new Array[Int](n * F)
    var i = 0
    while (i < n * F) { s = lcg(s); sample(i) = (s % 256).toInt; i += 1 }

    var h     = 0L
    var total = 0L
    i = 0
    while (i < n) {
      val sbase = i * F
      var acc   = 0L
      b = 0
      while (b < B) {
        val tbase = b * NODES
        var node  = 0
        var d     = 0
        while (d < D) {
          node = if (sample(sbase + feat(tbase + node)) <= thr(tbase + node))
            2 * node + 1
          else
            2 * node + 2
          d += 1
        }
        acc += leafval(tbase + node).toLong
        b += 1
      }
      h     = (h * 31 + acc + 1) % P
      total = (total + acc) % P
      i += 1
    }
    (h, total)
  }

  def main(args: Array[String]): Unit = {
    val n = if (args.nonEmpty) args(0).toInt else 5000
    val (h, total) = run(n)
    println(h)
    println(s"gbdt($n) = $total")
  }
}
