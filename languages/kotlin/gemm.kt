// gemm: quantized integer matrix-multiply - the dominant ML inference kernel.
// Square matmul of side N (i.e. N x N matrices). Loop order i,k,j (pinned)
// so B is accessed row-sequentially. LCG fills A then B with values 0..127.
// Accumulator is 64-bit; checksum = poly-hash of C row-major mod 1e9+7.
// No BLAS / no library matmul - the explicit triple loop.

const val P = 1000000007L

fun lcg(s: Long): Long = (s * 1103515245L + 12345L) and 0x7fffffffL

fun gemm(n: Int): Pair<Long, Long> {
    val A = LongArray(n * n)
    val B = LongArray(n * n)
    val C = LongArray(n * n)

    var s = 42L
    for (i in 0 until n * n) { s = lcg(s); A[i] = s % 128 }
    for (i in 0 until n * n) { s = lcg(s); B[i] = s % 128 }

    // Pinned loop order i, k, j - B read row-sequentially.
    for (i in 0 until n) {
        for (k in 0 until n) {
            val a = A[i * n + k]
            val kn = k * n
            val base = i * n
            for (j in 0 until n) {
                C[base + j] += a * B[kn + j]
            }
        }
    }

    var h = 0L
    for (i in 0 until n * n) h = (h * 31 + C[i] % P) % P
    val secondary = C[n * n - 1] % P
    return Pair(h, secondary)
}

fun main(args: Array<String>) {
    val n = if (args.isNotEmpty()) args[0].toInt() else 256
    val (h, sec) = gemm(n)
    println(h)
    println("gemm($n) = $sec")
}
