// bigint: hand-rolled multi-precision arithmetic - the carry-propagation axis. Compute N! as an
// array of base-2^32 limbs by repeated bignum*smallint multiplication (each limb: cur = limb*k +
// carry; store low 32 bits, propagate the high bits), then poly-hash the limbs. Implemented by hand
// (NO native/library big integers - no java.math.BigInteger), so it measures raw multi-word
// arithmetic. All integer-deterministic. Kotlin IntArray holds 32-bit limbs; the limb is read back
// as unsigned via `and 0xFFFFFFFFL`, and cur = limb*k + carry uses a 64-bit Long intermediate.

const val P = 1000000007L

fun bigint(n: Int): Long {
    val limbs = IntArray(n + 64)                          // base 2^32, least-significant limb first
    limbs[0] = 1
    var len = 1
    for (k in 2..n) {
        var carry = 0L                                    // 64-bit carry
        for (i in 0 until len) {
            val cur = (limbs[i].toLong() and 0xFFFFFFFFL) * k.toLong() + carry   // ~2^46, fits in Long
            limbs[i] = (cur and 0xFFFFFFFFL).toInt()      // low 32 bits
            carry = cur ushr 32                           // high bits propagate
        }
        while (carry > 0L) {
            limbs[len++] = (carry and 0xFFFFFFFFL).toInt()
            carry = carry ushr 32
        }
    }
    var h = 0L
    for (i in 0 until len) h = (h * 31 + (limbs[i].toLong() and 0xFFFFFFFFL)) % P   // poly-hash, LSL first
    return h
}

fun main(args: Array<String>) {
    val n = if (args.isNotEmpty()) args[0].toInt() else 6000
    println(bigint(n))
    println("bigint($n)")
}
