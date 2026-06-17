// k-means: Lloyd's clustering algorithm - the machine-learning axis of the suite. Cluster N
// integer D-dimensional points into K clusters over ITERS fixed iterations: assign each point
// to its nearest centroid (integer squared Euclidean distance), then recompute each centroid as
// the floor-mean of its members. Everything is integer (quantized-style) - deterministic, no
// floating point, so no FMA / summation-order divergence across languages.
//
// Pinned tie-breaks: a point ties to the LOWEST-index centroid (strict < while scanning); an
// empty cluster keeps its centroid unchanged. The checksum hashes the final centroids and the
// final assignment of every point. Hand-written assign/update loops - no ML/numeric library.
object KMeans {
  final val P = 1000000007L
  final val K = 16
  final val D = 4
  final val ITERS = 10
  final val RANGE = 256L

  def lcgNext(s: Long): Long = (s * 1103515245L + 12345L) & 0x7fffffffL

  def kMeans(n: Int): Long = {
    // 1. Generate N integer D-dimensional points with the pinned LCG.
    val pt = new Array[Long](n * D)
    var state = 42L
    var i = 0
    while (i < n * D) { state = lcgNext(state); pt(i) = state % RANGE; i += 1 }

    val cen = new Array[Long](K * D)             // initial centroids = first K points
    i = 0
    while (i < K * D) { cen(i) = pt(i); i += 1 }

    val assign = new Array[Int](n)
    val ssum = new Array[Long](K * D)            // 64-bit per-cluster sums
    val cnt = new Array[Long](K)

    // 2. ITERS iterations of assign + update.
    var iter = 0
    while (iter < ITERS) {
      i = 0
      while (i < n) {                            // assignment - nearest centroid
        var best = 0
        var bd = -1L
        var k = 0
        while (k < K) {
          var dist = 0L
          var d = 0
          while (d < D) {
            val df = pt(i * D + d) - cen(k * D + d)
            dist += df * df
            d += 1
          }
          if (bd < 0 || dist < bd) { bd = dist; best = k }  // STRICT < : ties to lowest k
          k += 1
        }
        assign(i) = best
        i += 1
      }

      var k = 0                                  // update - floor-mean, empty unchanged
      while (k < K * D) { ssum(k) = 0L; k += 1 }
      k = 0
      while (k < K) { cnt(k) = 0L; k += 1 }
      i = 0
      while (i < n) {
        val ki = assign(i)
        cnt(ki) += 1
        var d = 0
        while (d < D) { ssum(ki * D + d) += pt(i * D + d); d += 1 }
        i += 1
      }
      k = 0
      while (k < K) {
        if (cnt(k) > 0) {
          var d = 0
          while (d < D) { cen(k * D + d) = ssum(k * D + d) / cnt(k); d += 1 }  // floor div
        }
        // else leave centroid[k] unchanged (empty cluster)
        k += 1
      }
      iter += 1
    }

    // 3. Final assignment with the final centroids.
    i = 0
    while (i < n) {
      var best = 0
      var bd = -1L
      var k = 0
      while (k < K) {
        var dist = 0L
        var d = 0
        while (d < D) {
          val df = pt(i * D + d) - cen(k * D + d)
          dist += df * df
          d += 1
        }
        if (bd < 0 || dist < bd) { bd = dist; best = k }
        k += 1
      }
      assign(i) = best
      i += 1
    }

    // Checksum: hash the final centroids, then every point's assignment.
    var h = 0L
    i = 0
    while (i < K * D) { h = (h * 31 + cen(i)) % P; i += 1 }
    i = 0
    while (i < n) { h = (h * 31 + assign(i)) % P; i += 1 }
    h
  }

  def main(args: Array[String]): Unit = {
    val n = if (args.nonEmpty) args(0).toInt else 8000
    println(kMeans(n))
    println(s"k-means($n)")
  }
}
