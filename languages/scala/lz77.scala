// lz77: a hand-written LZ77 compressor - the data-compression / sliding-window axis.
// Generate N bytes from a small alphabet (LCG, so matches are common); at each position
// scan the previous WINDOW bytes for the longest match (closest distance wins ties), emit
// a (distance, length) back-reference or a literal, and advance greedily. Fold the whole
// token stream into a polynomial hash. The brute-force O(N*WINDOW) longest-match search is
// written out explicitly (no compression library, no hash-chain/suffix-tree). All integer;
// the only 64-bit value is the poly-hash accumulator (h*31).
object Lz77 {
  final val P = 1000000007L
  final val WINDOW = 512
  final val MIN_MATCH = 3
  final val MAX_MATCH = 255
  final val ALPHA = 6

  def lcg(s: Long): Long = (s * 1103515245L + 12345L) & 0x7fffffffL

  def lz77(n: Int): Long = {
    val in = new Array[Int](n)
    var state = 42L
    var i = 0
    while (i < n) { state = lcg(state); in(i) = (state % ALPHA).toInt; i += 1 }

    var pos = 0
    var h = 0L
    while (pos < n) {
      var bestLen = 0
      var bestDist = 0
      var start = pos - WINDOW
      if (start < 0) start = 0
      var cand = pos - 1
      while (cand >= start) {                       // nearest distance first
        var l = 0
        while (pos + l < n && l < MAX_MATCH && in(cand + l) == in(pos + l)) l += 1
        if (l > bestLen) { bestLen = l; bestDist = pos - cand }   // strict > : closest wins ties
        cand -= 1
      }
      if (bestLen >= MIN_MATCH) {
        h = (h * 31 + 1) % P; h = (h * 31 + bestDist) % P; h = (h * 31 + bestLen) % P
        pos += bestLen
      } else {
        h = (h * 31 + 0) % P; h = (h * 31 + in(pos)) % P
        pos += 1
      }
    }
    h
  }

  def main(args: Array[String]): Unit = {
    val n = if (args.nonEmpty) args(0).toInt else 24000
    println(lz77(n))
    println(s"lz77($n)")
  }
}
