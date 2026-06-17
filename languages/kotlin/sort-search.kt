// sort-search: generate N integers, sort them with a hand-written median-of-three
// quicksort (Hoare partition), then run N binary searches and fold the found indices
// into a checksum. The two classic algorithms - quicksort and binary search - written
// out explicitly (no stdlib sort/binarySearch), so this measures the LANGUAGE executing
// the SAME algorithm, consistent with the suite's no-stdlib-shortcut rule. All integer.

const val P = 1000000007L

fun lcgNext(s: Long): Long = (s * 1103515245L + 12345L) and 0x7fffffffL

fun swap(a: LongArray, i: Int, j: Int) {
    val t = a[i]; a[i] = a[j]; a[j] = t
}

// median-of-three + Hoare partition, recurse both sides; depth stays ~log N.
fun qsortH(a: LongArray, lo: Int, hi: Int) {
    if (lo >= hi) return
    val mid = lo + (hi - lo) / 2
    if (a[mid] < a[lo]) swap(a, lo, mid)
    if (a[hi] < a[lo]) swap(a, lo, hi)
    if (a[hi] < a[mid]) swap(a, mid, hi)
    val pivot = a[mid]
    var i = lo - 1
    var j = hi + 1
    while (true) {
        do { i++ } while (a[i] < pivot)
        do { j-- } while (a[j] > pivot)
        if (i >= j) break
        swap(a, i, j)
    }
    qsortH(a, lo, j)
    qsortH(a, j + 1, hi)
}

fun bsearchI(a: LongArray, n: Int, key: Long): Int {
    var lo = 0
    var hi = n - 1
    while (lo <= hi) {
        val mid = lo + (hi - lo) / 2
        if (a[mid] < key) lo = mid + 1
        else if (a[mid] > key) hi = mid - 1
        else return mid
    }
    return -1
}

fun sortSearch(n: Int): Long {
    val a = LongArray(n)
    var state = 42L
    for (i in 0 until n) {
        state = lcgNext(state)
        a[i] = state
    }
    qsortH(a, 0, n - 1)
    var h = 0L
    for (q in 0 until n) {
        state = lcgNext(state)
        val key = a[(state % n).toInt()]   // a value present in the sorted array -> a hit
        val idx = bsearchI(a, n, key)
        h = (h * 31 + (idx + 1)) % P
    }
    return h
}

fun main(args: Array<String>) {
    val n = if (args.isNotEmpty()) args[0].toInt() else 100000
    println(sortSearch(n))
    println("sort-search($n)")
}
