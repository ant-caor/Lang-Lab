// tak: the Takeuchi function - the function-call / recursion-overhead axis of the suite.
// Naive recursive tak(x,y,z): three recursive calls per non-base node, NO memoization, NO
// iterative/tail rewrite. It touches no arrays and allocates nothing - the ONLY thing it
// stresses is the cost of a function call + return + a couple of integer compares/decrements.
// The size n maps to the classic shape tak(3n, 2n, n).
//
// Checksum = the TOTAL number of calls (counted at entry, before the base test; eager
// evaluation means all three inner calls always run). Secondary = the returned value. All
// integer; values stay tiny (no overflow).
object Tak {
  // Module-level call counter (like C's `static long calls`).
  var calls: Long = 0L

  def tak(x: Int, y: Int, z: Int): Int = {
    calls += 1
    if (y < x) tak(tak(x - 1, y, z), tak(y - 1, z, x), tak(z - 1, x, y))
    else z
  }

  def main(args: Array[String]): Unit = {
    val n = if (args.nonEmpty) args(0).toInt else 6
    val r = tak(3 * n, 2 * n, n)
    println(calls)
    println(s"tak($n) = $r")
  }
}
