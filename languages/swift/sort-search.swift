import Foundation

// sort-search: generate N integers, sort them with a hand-written median-of-three
// quicksort (Hoare partition), then run N binary searches and fold the found indices
// into a checksum. The two classic algorithms - quicksort and binary search - written
// out explicitly (no stdlib sort/sorted/bsearch), so this measures the LANGUAGE
// executing the SAME algorithm, consistent with the suite's no-stdlib-shortcut rule.
// All integer.

let P = 1000000007

func lcgNext(_ s: Int) -> Int {
    return (s &* 1103515245 &+ 12345) & 0x7fffffff
}

func swapAt(_ a: inout [Int], _ i: Int, _ j: Int) {
    let t = a[i]; a[i] = a[j]; a[j] = t
}

// median-of-three + Hoare partition, recurse both sides; depth stays ~log N.
func qsortH(_ a: inout [Int], _ lo: Int, _ hi: Int) {
    if lo >= hi { return }
    let mid = lo + (hi - lo) / 2
    if a[mid] < a[lo] { swapAt(&a, lo, mid) }
    if a[hi]  < a[lo] { swapAt(&a, lo, hi) }
    if a[hi]  < a[mid] { swapAt(&a, mid, hi) }
    let pivot = a[mid]
    var i = lo - 1, j = hi + 1
    while true {
        repeat { i += 1 } while a[i] < pivot
        repeat { j -= 1 } while a[j] > pivot
        if i >= j { break }
        swapAt(&a, i, j)
    }
    qsortH(&a, lo, j)
    qsortH(&a, j + 1, hi)
}

func bsearchI(_ a: [Int], _ n: Int, _ key: Int) -> Int {
    var lo = 0, hi = n - 1
    while lo <= hi {
        let mid = lo + (hi - lo) / 2
        if a[mid] < key { lo = mid + 1 }
        else if a[mid] > key { hi = mid - 1 }
        else { return mid }
    }
    return -1
}

let n = CommandLine.arguments.count > 1 ? (Int(CommandLine.arguments[1]) ?? 100000) : 100000

var a = [Int](repeating: 0, count: n)
var state = 42
for i in 0..<n {
    state = lcgNext(state)
    a[i] = state
}
qsortH(&a, 0, n - 1)
var h = 0
for _ in 0..<n {
    state = lcgNext(state)
    let key = a[state % n]            // a value present in the sorted array -> a hit
    let idx = bsearchI(a, n, key)
    h = (h * 31 + (idx + 1)) % P
}
print(h)
print("sort-search(\(n))")
