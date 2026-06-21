// gemm: quantized integer matrix-multiply - the dominant ML inference kernel.
// Square matmul of side N (i.e. N x N matrices). Loop order i,k,j (pinned)
// so B is accessed row-sequentially. LCG fills A then B with values 0..127.
// Accumulator is 64-bit; checksum = poly-hash of C row-major mod 1e9+7.
// No BLAS / no breeze / no nd4j / no library matmul - the explicit triple loop.
object Gemm {
  final val P = 1000000007L

  def lcgNext(s: Long): Long = (s * 1103515245L + 12345L) & 0x7fffffffL

  def gemm(n: Int): (Long, Long) = {
    val A = new Array[Long](n * n)
    val B = new Array[Long](n * n)
    val C = new Array[Long](n * n)

    var state = 42L
    var i = 0
    while (i < n * n) { state = lcgNext(state); A(i) = state % 128; i += 1 }
    i = 0
    while (i < n * n) { state = lcgNext(state); B(i) = state % 128; i += 1 }

    // Pinned loop order i, k, j - B read row-sequentially.
    i = 0
    while (i < n) {
      var k = 0
      while (k < n) {
        val a = A(i * n + k)
        val kn = k * n
        val base = i * n
        var j = 0
        while (j < n) {
          C(base + j) += a * B(kn + j)
          j += 1
        }
        k += 1
      }
      i += 1
    }

    var h = 0L
    i = 0
    while (i < n * n) { h = (h * 31 + C(i) % P) % P; i += 1 }
    val secondary = C(n * n - 1) % P
    (h, secondary)
  }

  def main(args: Array[String]): Unit = {
    val n = if (args.nonEmpty) args(0).toInt else 256
    val (h, sec) = gemm(n)
    println(h)
    println(s"gemm($n) = $sec")
  }
}
