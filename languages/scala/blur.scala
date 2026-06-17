object Blur {
  final val P = 1000000007L
  final val PASSES = 4

  def lcg(s: Long): Long = (s * 1103515245L + 12345L) & 0x7fffffffL

  def clampi(x: Int, n: Int): Int = if (x < 0) 0 else if (x >= n) n - 1 else x

  def blur(n: Int): Long = {
    val k = Array(1, 2, 1, 2, 4, 2, 1, 2, 1) // 3x3, sum 16
    var src = new Array[Int](n * n)
    var dst = new Array[Int](n * n)

    var s = 42L
    var idx = 0
    while (idx < n * n) { s = lcg(s); src(idx) = (s % 256).toInt; idx += 1 }

    var pass = 0
    while (pass < PASSES) {
      var i = 0
      while (i < n) {
        var j = 0
        while (j < n) {
          var acc = 0
          var di = -1
          while (di <= 1) {
            val ni = clampi(i + di, n)
            var dj = -1
            while (dj <= 1) {
              val nj = clampi(j + dj, n)
              acc += k((di + 1) * 3 + (dj + 1)) * src(ni * n + nj)
              dj += 1
            }
            di += 1
          }
          dst(i * n + j) = acc / 16 // integer division
          j += 1
        }
        i += 1
      }
      val t = src; src = dst; dst = t // double-buffer swap (refs, no copy)
      pass += 1
    }

    var h = 0L
    var p = 0
    while (p < n * n) { h = (h * 31 + src(p)) % P; p += 1 }
    h
  }

  def main(args: Array[String]): Unit = {
    val n = if (args.nonEmpty) args(0).toInt else 256
    println(blur(n))
    println(s"blur($n)")
  }
}
