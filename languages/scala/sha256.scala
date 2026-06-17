// sha256: iterated SHA-256 - the bit-manipulation / cryptography axis of the suite. Start from
// a 32-byte LCG-generated digest and apply real FIPS 180-4 SHA-256 to it N times (each hash is a
// single padded block). The hot path is rotations, XOR, shifts and modular 2^32 addition - work
// no other benchmark does. Hand-written (no crypto library); the checksum is a poly-hash of the
// final 32-byte digest. Int is 32-bit and wraps on add; right shifts use >>> (logical, zero-fill).
object Sha256 {
  final val P = 1000000007L

  val K: Array[Int] = Array(
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2)

  val H0: Array[Int] = Array(
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19)

  def rotr(x: Int, n: Int): Int = (x >>> n) | (x << (32 - n))

  def sha256Block(b: Array[Int], h: Array[Int]): Unit = {
    val w = new Array[Int](64)
    var i = 0
    while (i < 16) {
      w(i) = (b(i * 4) << 24) | (b(i * 4 + 1) << 16) | (b(i * 4 + 2) << 8) | b(i * 4 + 3)
      i += 1
    }
    i = 16
    while (i < 64) {
      val s0 = rotr(w(i - 15), 7) ^ rotr(w(i - 15), 18) ^ (w(i - 15) >>> 3)
      val s1 = rotr(w(i - 2), 17) ^ rotr(w(i - 2), 19) ^ (w(i - 2) >>> 10)
      w(i) = w(i - 16) + s0 + w(i - 7) + s1
      i += 1
    }
    var a = h(0); var bb = h(1); var c = h(2); var d = h(3)
    var e = h(4); var f = h(5); var g = h(6); var hh = h(7)
    i = 0
    while (i < 64) {
      val s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
      val ch = (e & f) ^ (~e & g)
      val t1 = hh + s1 + ch + K(i) + w(i)
      val s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
      val maj = (a & bb) ^ (a & c) ^ (bb & c)
      val t2 = s0 + maj
      hh = g; g = f; f = e; e = d + t1; d = c; c = bb; bb = a; a = t1 + t2
      i += 1
    }
    h(0) += a; h(1) += bb; h(2) += c; h(3) += d; h(4) += e; h(5) += f; h(6) += g; h(7) += hh
  }

  // hash the 32-byte digest in place (one padded 64-byte block; message length = 256 bits)
  def sha256_32(digest: Array[Int]): Unit = {
    val b = new Array[Int](64)
    var i = 0
    while (i < 32) { b(i) = digest(i); i += 1 }
    b(32) = 0x80
    i = 33
    while (i < 64) { b(i) = 0; i += 1 }
    b(62) = 1 // length 256 = 0x0100
    val h = new Array[Int](8)
    i = 0
    while (i < 8) { h(i) = H0(i); i += 1 }
    sha256Block(b, h)
    i = 0
    while (i < 8) {
      digest(i * 4) = (h(i) >>> 24) & 0xff
      digest(i * 4 + 1) = (h(i) >>> 16) & 0xff
      digest(i * 4 + 2) = (h(i) >>> 8) & 0xff
      digest(i * 4 + 3) = h(i) & 0xff
      i += 1
    }
  }

  def main(args: Array[String]): Unit = {
    val n = if (args.nonEmpty) args(0).toInt else 10000
    val d = new Array[Int](32)
    var s = 42L
    var i = 0
    while (i < 32) {
      s = (s * 1103515245L + 12345L) & 0x7fffffffL
      d(i) = (s % 256).toInt
      i += 1
    }
    i = 0
    while (i < n) { sha256_32(d); i += 1 }
    var h = 0L
    i = 0
    while (i < 32) { h = (h * 31 + d(i)) % P; i += 1 }
    println(h)
    println(s"sha256($n)")
  }
}
