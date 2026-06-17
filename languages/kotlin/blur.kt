// blur: a 2D image-convolution benchmark - the stencil axis of the suite. Generate a
// grayscale N x N image, then apply a 3x3 Gaussian blur kernel [1 2 1; 2 4 2; 1 2 1]/16
// PASSES times (double-buffered), with clamp (edge-replication) border handling, and reduce
// the result to a polynomial hash. All integer arithmetic - deterministic, no floating point.

const val P = 1000000007L
const val PASSES = 4

fun lcg(s: Long): Long = (s * 1103515245L + 12345L) and 0x7fffffffL
fun clampi(x: Int, n: Int): Int = if (x < 0) 0 else if (x >= n) n - 1 else x

fun blur(n: Int): Long {
    val k = intArrayOf(1, 2, 1, 2, 4, 2, 1, 2, 1)   // 3x3, sum 16
    var src = IntArray(n * n)
    var dst = IntArray(n * n)
    var s = 42L
    for (idx in 0 until n * n) {
        s = lcg(s)
        src[idx] = (s % 256).toInt()
    }
    repeat(PASSES) {
        for (i in 0 until n) {
            for (j in 0 until n) {
                var acc = 0
                for (di in -1..1) {
                    val ni = clampi(i + di, n)
                    for (dj in -1..1) {
                        val nj = clampi(j + dj, n)
                        acc += k[(di + 1) * 3 + (dj + 1)] * src[ni * n + nj]
                    }
                }
                dst[i * n + j] = acc / 16   // integer division
            }
        }
        val t = src; src = dst; dst = t     // double-buffer swap
    }
    var h = 0L
    for (idx in 0 until n * n) {
        h = (h * 31 + src[idx]) % P
    }
    return h
}

fun main(args: Array<String>) {
    val n = if (args.isNotEmpty()) args[0].toInt() else 256
    println(blur(n))
    println("blur($n)")
}
