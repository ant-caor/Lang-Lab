// sort-search: generate N integers, sort them with a hand-written median-of-three
// quicksort (Hoare partition), then run N binary searches and fold the found indices
// into a checksum. The two classic algorithms - quicksort and binary search - written
// out explicitly (no stdlib sort/sorted/search), so this measures the LANGUAGE executing
// the SAME algorithm, consistent with the suite's no-stdlib-shortcut rule. All integer.
object SortSearch {
  final val P = 1000000007L

  def lcgNext(s: Long): Long = (s * 1103515245L + 12345L) & 0x7fffffffL

  def swap(a: Array[Long], i: Int, j: Int): Unit = {
    val t = a(i); a(i) = a(j); a(j) = t
  }

  // median-of-three + Hoare partition, recurse both sides; depth stays ~log N.
  def qsortH(a: Array[Long], lo: Int, hi: Int): Unit = {
    if (lo >= hi) return
    val mid = lo + (hi - lo) / 2
    if (a(mid) < a(lo)) swap(a, lo, mid)
    if (a(hi)  < a(lo)) swap(a, lo, hi)
    if (a(hi)  < a(mid)) swap(a, mid, hi)
    val pivot = a(mid)
    var i = lo - 1
    var j = hi + 1
    var done = false
    while (!done) {
      // Scala 3 removed `do { } while`; `while ({ body; cond }) ()` is the equivalent
      // (run the increment, then test) - same bump-then-test as the C Hoare scan.
      while ({ i += 1; a(i) < pivot }) ()
      while ({ j -= 1; a(j) > pivot }) ()
      if (i >= j) done = true
      else swap(a, i, j)
    }
    qsortH(a, lo, j)
    qsortH(a, j + 1, hi)
  }

  def bsearch(a: Array[Long], n: Int, key: Long): Int = {
    var lo = 0
    var hi = n - 1
    while (lo <= hi) {
      val mid = lo + (hi - lo) / 2
      if (a(mid) < key) lo = mid + 1
      else if (a(mid) > key) hi = mid - 1
      else return mid
    }
    -1
  }

  def sortSearch(n: Int): Long = {
    val a = new Array[Long](n)
    var state = 42L
    var i = 0
    while (i < n) { state = lcgNext(state); a(i) = state; i += 1 }
    qsortH(a, 0, n - 1)
    var h = 0L
    var q = 0
    while (q < n) {
      state = lcgNext(state)
      val key = a((state % n).toInt)        // a value present in the sorted array -> a hit
      val idx = bsearch(a, n, key)
      h = (h * 31 + (idx + 1)) % P
      q += 1
    }
    h
  }

  def main(args: Array[String]): Unit = {
    val n = if (args.nonEmpty) args(0).toInt else 100000
    println(sortSearch(n))
    println(s"sort-search($n)")
  }
}
