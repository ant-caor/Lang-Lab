object Fannkuch {
  def fannkuch(n: Int): (Int, Int) = {
    val perm1 = Array.tabulate(n)(identity)
    val perm = new Array[Int](n)
    val count = new Array[Int](n)
    var maxFlips = 0
    var checksum = 0
    var permIdx = 0L  // counts up to n!-1 → needs 64-bit for n >= 13
    var r = n

    while (true) {
      while (r != 1) { count(r - 1) = r; r -= 1 }

      System.arraycopy(perm1, 0, perm, 0, n)
      var flips = 0
      var k = perm(0)
      while (k != 0) {
        var i = 0; var j = k
        while (i < j) { val t = perm(i); perm(i) = perm(j); perm(j) = t; i += 1; j -= 1 }
        flips += 1
        k = perm(0)
      }

      if (flips > maxFlips) maxFlips = flips
      checksum += (if (permIdx % 2 == 0L) flips else -flips)

      // Generate the next permutation.
      var advanced = false
      while (!advanced) {
        if (r == n) return (maxFlips, checksum)
        val first = perm1(0)
        var i = 0
        while (i < r) { perm1(i) = perm1(i + 1); i += 1 }
        perm1(r) = first
        count(r) -= 1
        if (count(r) > 0) advanced = true else r += 1
      }
      permIdx += 1
    }
    (maxFlips, checksum) // unreachable; satisfies the type checker
  }

  def main(args: Array[String]): Unit = {
    val n = if (args.nonEmpty) args(0).toInt else 7
    val (maxFlips, checksum) = fannkuch(n)
    println(checksum)
    println(s"Pfannkuchen($n) = $maxFlips")
  }
}
