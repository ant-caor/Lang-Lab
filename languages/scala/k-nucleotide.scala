import scala.collection.mutable

object KNucleotide {
  final val K = 8
  final val P = 1000000007L
  final val IM = 139968L
  final val IA = 3877L
  final val IC = 29573L

  // Deterministic DNA sequence via an integer LCG (no floating point).
  def gen(l: Int): Array[Char] = {
    val s = new Array[Char](l)
    var seed = 42L
    var i = 0
    while (i < l) {
      seed = (seed * IA + IC) % IM
      s(i) = if (seed < 42000) 'A' else if (seed < 70000) 'C' else if (seed < 98000) 'G' else 'T'
      i += 1
    }
    s
  }

  def code(c: Char): Long = c match {
    case 'A' => 0L
    case 'C' => 1L
    case 'G' => 2L
    case _   => 3L
  }

  def kNucleotide(l: Int): Long = {
    val s = gen(l)

    // Count every K-mer in the idiomatic built-in hash map, keyed by the
    // K-character substring (string) - no direct-addressing shortcut.
    val map = mutable.HashMap.empty[String, Long]
    var i = 0
    while (i + K <= l) {
      val kmer = new String(s, i, K)
      map(kmer) = map.getOrElse(kmer, 0L) + 1L
      i += 1
    }

    // Order-independent checksum: sum of encode(kmer)*count mod P.
    // e is up to 65535 and count is up to L, so e*count overflows 32-bit -
    // everything here is Long (64-bit).
    var acc = 0L
    for ((kmer, count) <- map) {
      var e = 0L
      var j = 0
      while (j < K) {
        e = e * 4L + code(kmer.charAt(j))
        j += 1
      }
      acc = (acc + e * count) % P
    }
    acc
  }

  def main(args: Array[String]): Unit = {
    val l = if (args.nonEmpty) args(0).toInt else 100000
    println(kNucleotide(l))
    println(s"k-nucleotide($l)")
  }
}
