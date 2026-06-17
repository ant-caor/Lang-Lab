// sha256: iterated SHA-256 - the bit-manipulation / cryptography axis of the suite. Start from
// a 32-byte LCG-generated digest and apply real FIPS 180-4 SHA-256 to it N times (each hash is a
// single padded block). The hot path is rotations, XOR, shifts and modular 2^32 addition - work
// no other benchmark does. Hand-written (no crypto library); the checksum is a poly-hash of the
// final 32-byte digest. Kotlin Int is 32-bit and wraps; right shifts MUST be ushr (logical).

const val P = 1000000007L

val K = intArrayOf(
    0x428a2f98.toInt(), 0x71374491, 0xb5c0fbcf.toInt(), 0xe9b5dba5.toInt(), 0x3956c25b, 0x59f111f1, 0x923f82a4.toInt(), 0xab1c5ed5.toInt(),
    0xd807aa98.toInt(), 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe.toInt(), 0x9bdc06a7.toInt(), 0xc19bf174.toInt(),
    0xe49b69c1.toInt(), 0xefbe4786.toInt(), 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152.toInt(), 0xa831c66d.toInt(), 0xb00327c8.toInt(), 0xbf597fc7.toInt(), 0xc6e00bf3.toInt(), 0xd5a79147.toInt(), 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e.toInt(), 0x92722c85.toInt(),
    0xa2bfe8a1.toInt(), 0xa81a664b.toInt(), 0xc24b8b70.toInt(), 0xc76c51a3.toInt(), 0xd192e819.toInt(), 0xd6990624.toInt(), 0xf40e3585.toInt(), 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814.toInt(), 0x8cc70208.toInt(), 0x90befffa.toInt(), 0xa4506ceb.toInt(), 0xbef9a3f7.toInt(), 0xc67178f2.toInt()
)

val H0 = intArrayOf(
    0x6a09e667, 0xbb67ae85.toInt(), 0x3c6ef372, 0xa54ff53a.toInt(),
    0x510e527f, 0x9b05688c.toInt(), 0x1f83d9ab, 0x5be0cd19
)

fun rotr(x: Int, n: Int): Int = (x ushr n) or (x shl (32 - n))

fun sha256Block(b: ByteArray, h: IntArray) {
    val w = IntArray(64)
    for (i in 0 until 16) {
        w[i] = ((b[i * 4].toInt() and 0xff) shl 24) or
               ((b[i * 4 + 1].toInt() and 0xff) shl 16) or
               ((b[i * 4 + 2].toInt() and 0xff) shl 8) or
               (b[i * 4 + 3].toInt() and 0xff)
    }
    for (i in 16 until 64) {
        val s0 = rotr(w[i - 15], 7) xor rotr(w[i - 15], 18) xor (w[i - 15] ushr 3)
        val s1 = rotr(w[i - 2], 17) xor rotr(w[i - 2], 19) xor (w[i - 2] ushr 10)
        w[i] = w[i - 16] + s0 + w[i - 7] + s1
    }
    var a = h[0]; var bb = h[1]; var c = h[2]; var d = h[3]
    var e = h[4]; var f = h[5]; var g = h[6]; var hh = h[7]
    for (i in 0 until 64) {
        val s1 = rotr(e, 6) xor rotr(e, 11) xor rotr(e, 25)
        val ch = (e and f) xor (e.inv() and g)
        val t1 = hh + s1 + ch + K[i] + w[i]
        val s0 = rotr(a, 2) xor rotr(a, 13) xor rotr(a, 22)
        val maj = (a and bb) xor (a and c) xor (bb and c)
        val t2 = s0 + maj
        hh = g; g = f; f = e; e = d + t1; d = c; c = bb; bb = a; a = t1 + t2
    }
    h[0] += a; h[1] += bb; h[2] += c; h[3] += d
    h[4] += e; h[5] += f; h[6] += g; h[7] += hh
}

// hash the 32-byte digest in place (one padded 64-byte block; message length = 256 bits)
fun sha256_32(digest: ByteArray) {
    val b = ByteArray(64)
    for (i in 0 until 32) b[i] = digest[i]
    b[32] = 0x80.toByte()
    for (i in 33 until 64) b[i] = 0
    b[62] = 1                                   // length 256 = 0x0100
    val h = IntArray(8)
    for (i in 0 until 8) h[i] = H0[i]
    sha256Block(b, h)
    for (i in 0 until 8) {
        digest[i * 4] = (h[i] ushr 24).toByte()
        digest[i * 4 + 1] = (h[i] ushr 16).toByte()
        digest[i * 4 + 2] = (h[i] ushr 8).toByte()
        digest[i * 4 + 3] = h[i].toByte()
    }
}

fun main(args: Array<String>) {
    val n = if (args.isNotEmpty()) args[0].toInt() else 10000
    val d = ByteArray(32)
    var s = 42L
    for (i in 0 until 32) {
        s = (s * 1103515245L + 12345L) and 0x7fffffffL
        d[i] = (s % 256).toByte()
    }
    for (i in 0 until n) sha256_32(d)
    var h = 0L
    for (i in 0 until 32) h = (h * 31 + (d[i].toInt() and 0xff)) % P
    println(h)
    println("sha256($n)")
}
