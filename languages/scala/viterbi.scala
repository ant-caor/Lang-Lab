// viterbi: integer HMM sequence decoding — the classical max-plus trellis.
// S=8 states, ALPHA=4 symbols, T=size parameter. LCG (glibc-style, seed=42)
// draws trans[S*S], emit[S*ALPHA], obs[T] in that order. Forward pass is a
// loop-carried max-reduction (STRICT > tie-break: lowest i wins), followed by
// a pointer-chain backtrace. Checksum = poly-hash of (path[t]+1).
// Secondary = optimal total path score mod P. No HMM library; pure integer.
object Viterbi {
  final val SV    = 8
  final val ALPHA = 4
  final val P     = 1000000007L

  def lcg(s: Long): Long = (s * 1103515245L + 12345L) & 0x7fffffffL

  def run(t: Int): (Long, Long) = {
    // Draw order: trans[S*S], emit[S*ALPHA], obs[T]
    val trans = new Array[Long](SV * SV)
    val emit  = new Array[Long](SV * ALPHA)
    val obs   = new Array[Int](t)
    var s = 42L
    var x = 0
    while (x < SV * SV)    { s = lcg(s); trans(x) = s % 100L + 1L; x += 1 }
    x = 0
    while (x < SV * ALPHA) { s = lcg(s); emit(x)  = s % 100L + 1L; x += 1 }
    var i = 0
    while (i < t)           { s = lcg(s); obs(i) = (s % ALPHA).toInt; i += 1 }

    // Initialise t=0
    var vitPrev = new Array[Long](SV)
    var vitNext = new Array[Long](SV)
    var j = 0
    while (j < SV) { vitPrev(j) = emit(j * ALPHA + obs(0)); j += 1 }

    val back = new Array[Int](t * SV)

    // Forward trellis t=1..T-1
    var ti = 1
    while (ti < t) {
      j = 0
      while (j < SV) {
        var best = -1L; var bi = 0
        val e = emit(j * ALPHA + obs(ti))
        i = 0
        while (i < SV) {
          val sc = vitPrev(i) + trans(i * SV + j) + e
          if (sc > best) { best = sc; bi = i }   // STRICT > -> lowest i wins
          i += 1
        }
        vitNext(j) = best
        back(ti * SV + j) = bi
        j += 1
      }
      val tmp = vitPrev; vitPrev = vitNext; vitNext = tmp
      ti += 1
    }

    // Final state: STRICT > -> lowest j wins
    var bf = 0
    j = 1
    while (j < SV) { if (vitPrev(j) > vitPrev(bf)) bf = j; j += 1 }

    // Backtrace
    val path = new Array[Int](t)
    path(t - 1) = bf
    ti = t - 2
    while (ti >= 0) { path(ti) = back((ti + 1) * SV + path(ti + 1)); ti -= 1 }

    // Checksum
    var h = 0L
    ti = 0
    while (ti < t) { h = (h * 31L + path(ti) + 1L) % P; ti += 1 }

    val secondary = vitPrev(bf) % P
    (h, secondary)
  }

  def main(args: Array[String]): Unit = {
    val t = if (args.nonEmpty) args(0).toInt else 20000
    val (h, sec) = run(t)
    println(h)
    println(s"viterbi($t) = $sec")
  }
}
