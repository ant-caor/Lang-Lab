// dijkstra: single-source shortest paths on a deterministically generated weighted
// digraph, using a HAND-WRITTEN binary min-heap (no stdlib priority queue). The graph
// axis of the suite - it stresses the heap + adjacency-list traversal + relaxation loop.
//
// The heap stores PACKED keys: key = dist * 2^21 + node. Comparing keys as plain Longs
// is exactly the (dist, node) lexicographic order, and the keys are all UNIQUE (a node is
// only re-pushed when its distance strictly improves), so the heap behaviour - and thus the
// operation count - is identical in every language. The checksum is a hash of the final
// distance array, which is unique for Dijkstra regardless of heap internals. All integer.
object Dijkstra {
  final val P    = 1000000007L
  final val INF  = 1L << 62      // 2^62
  final val DEG  = 8             // average out-degree -> M = DEG*N directed edges
  final val MAXW = 100           // edge weights 1..MAXW
  final val BASE = 2097152L      // 2^21, larger than N; node packs into the low bits

  def lcgNext(s: Long): Long = (s * 1103515245L + 12345L) & 0x7fffffffL

  // hand-written binary min-heap of packed Long keys (all keys distinct).
  // backing array + size live as fields so push/pop are plain mutating methods.
  var heap: Array[Long] = null
  var hsize: Int = 0

  def hpush(k: Long): Unit = {
    var i = hsize
    hsize += 1
    heap(i) = k
    while (i > 0) {
      val p = (i - 1) / 2
      if (heap(p) <= heap(i)) return
      val t = heap(p); heap(p) = heap(i); heap(i) = t
      i = p
    }
  }

  def hpop(): Long = {
    val top = heap(0)
    hsize -= 1
    heap(0) = heap(hsize)
    var i = 0
    var done = false
    while (!done) {
      val l = 2 * i + 1
      val r = 2 * i + 2
      var m = i
      if (l < hsize && heap(l) < heap(m)) m = l
      if (r < hsize && heap(r) < heap(m)) m = r
      if (m == i) done = true
      else {
        val t = heap(m); heap(m) = heap(i); heap(i) = t
        i = m
      }
    }
    top
  }

  def dijkstra(n: Int): Long = {
    val m = DEG.toLong * n
    val eu = new Array[Int](m.toInt)
    val ev = new Array[Int](m.toInt)
    val ew = new Array[Int](m.toInt)
    var s = 42L
    var e = 0
    while (e < m) {
      s = lcgNext(s); eu(e) = (s % n).toInt
      s = lcgNext(s); ev(e) = (s % n).toInt
      s = lcgNext(s); ew(e) = (s % MAXW).toInt + 1
      e += 1
    }

    // CSR adjacency in forward (edge-generation) order
    val start = new Array[Int](n + 1)
    e = 0
    while (e < m) { start(eu(e) + 1) += 1; e += 1 }
    var i = 0
    while (i < n) { start(i + 1) += start(i); i += 1 }
    val cnt = new Array[Int](n)
    val adjV = new Array[Int](m.toInt)
    val adjW = new Array[Int](m.toInt)
    e = 0
    while (e < m) {
      val pos = start(eu(e)) + cnt(eu(e))
      cnt(eu(e)) += 1
      adjV(pos) = ev(e); adjW(pos) = ew(e)
      e += 1
    }

    val dist = new Array[Long](n)
    i = 0
    while (i < n) { dist(i) = INF; i += 1 }
    dist(0) = 0L

    heap = new Array[Long](m.toInt + 1); hsize = 0
    hpush(0L)                              // pack(0, 0) = 0
    while (hsize > 0) {
      val key = hpop()
      val d = key / BASE                   // integer division
      val u = (key % BASE).toInt           // integer modulo
      if (d <= dist(u)) {                  // skip stale heap entries
        var p = start(u)
        val pend = start(u + 1)
        while (p < pend) {
          val v = adjV(p)
          val nd = d + adjW(p)
          if (nd < dist(v)) {
            dist(v) = nd
            hpush(nd * BASE + v)
          }
          p += 1
        }
      }
    }

    var h = 0L
    i = 0
    while (i < n) {
      val di = if (dist(i) < INF) dist(i) else 0L   // unreachable -> 0
      h = (h * 31 + di % P) % P
      i += 1
    }
    h
  }

  def main(args: Array[String]): Unit = {
    val n = if (args.nonEmpty) args(0).toInt else 10000
    println(dijkstra(n))
    println(s"dijkstra($n)")
  }
}
