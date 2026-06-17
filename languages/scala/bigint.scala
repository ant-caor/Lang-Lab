// bigint: hand-rolled multi-precision arithmetic - the carry-propagation axis. Compute N! as an
// array of base-2^32 limbs by repeated bignum*smallint multiplication (each limb: cur = limb*k +
// carry; store low 32 bits, propagate the high bits), then poly-hash the limbs. Implemented by hand
// (NO native/library big integers - no java.math.BigInteger), so it measures raw multi-word
// arithmetic. All integer-deterministic. Limbs live in an Array[Int] (32-bit, unsigned via
// & 0xFFFFFFFFL); the cur = limb*k + carry intermediate is a Long.
object Bigint {
  final val P = 1000000007L

  def main(args: Array[String]): Unit = {
    val n = if (args.nonEmpty) args(0).toInt else 6000
    val limbs = new Array[Int](n + 64) // N! has ~N*log2(N)/32 limbs; N+64 is ample headroom
    var len = 1
    limbs(0) = 1
    var k = 2L
    while (k <= n) {
      var carry = 0L
      var i = 0
      while (i < len) {
        val cur = (limbs(i).toLong & 0xFFFFFFFFL) * k + carry // 64-bit intermediate (~2^46 here)
        limbs(i) = (cur & 0xFFFFFFFFL).toInt                  // low 32 bits
        carry = cur >>> 32                                    // high bits propagate
        i += 1
      }
      while (carry > 0L) {
        limbs(len) = (carry & 0xFFFFFFFFL).toInt
        len += 1
        carry = carry >>> 32
      }
      k += 1
    }
    var h = 0L
    var i = 0
    while (i < len) { h = (h * 31 + (limbs(i).toLong & 0xFFFFFFFFL)) % P; i += 1 } // poly-hash, LSL first
    println(h)
    println(s"bigint($n)")
  }
}
