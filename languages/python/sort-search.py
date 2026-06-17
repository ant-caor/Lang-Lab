# sort-search: generate N integers, sort them with a hand-written median-of-three
# quicksort (Hoare partition), then run N binary searches and fold the found indices
# into a checksum. The two classic algorithms - quicksort and binary search - written
# out explicitly (no stdlib sort/bisect), so this measures the LANGUAGE executing the
# SAME algorithm, consistent with the suite's no-stdlib-shortcut rule. All integer.
import sys

P = 1000000007


def lcg_next(s):
    return (s * 1103515245 + 12345) & 0x7FFFFFFF


# median-of-three + Hoare partition, recurse both sides; depth stays ~log N.
def qsort_h(a, lo, hi):
    if lo >= hi:
        return
    mid = lo + (hi - lo) // 2
    if a[mid] < a[lo]:
        a[lo], a[mid] = a[mid], a[lo]
    if a[hi] < a[lo]:
        a[lo], a[hi] = a[hi], a[lo]
    if a[hi] < a[mid]:
        a[mid], a[hi] = a[hi], a[mid]
    pivot = a[mid]
    i = lo - 1
    j = hi + 1
    while True:
        i += 1
        while a[i] < pivot:
            i += 1
        j -= 1
        while a[j] > pivot:
            j -= 1
        if i >= j:
            break
        a[i], a[j] = a[j], a[i]
    qsort_h(a, lo, j)
    qsort_h(a, j + 1, hi)


def bsearch_i(a, n, key):
    lo = 0
    hi = n - 1
    while lo <= hi:
        mid = lo + (hi - lo) // 2
        if a[mid] < key:
            lo = mid + 1
        elif a[mid] > key:
            hi = mid - 1
        else:
            return mid
    return -1


def sort_search(n):
    a = [0] * n
    state = 42
    for i in range(n):
        state = lcg_next(state)
        a[i] = state
    qsort_h(a, 0, n - 1)
    h = 0
    for _ in range(n):
        state = lcg_next(state)
        key = a[state % n]  # a value present in the sorted array -> a hit
        idx = bsearch_i(a, n, key)
        h = (h * 31 + (idx + 1)) % P
    return h


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
    sys.setrecursionlimit(1 << 20)
    print(sort_search(n))
    print("sort-search(%d)" % n)
