// sort-search: generate N integers, sort them with a hand-written median-of-three
// quicksort (Hoare partition), then run N binary searches and fold the found indices
// into a checksum. The two classic algorithms - quicksort and binary search - written
// out explicitly (no stdlib qsort/bsearch/sort), so this measures the LANGUAGE executing
// the SAME algorithm, consistent with the suite's no-stdlib-shortcut rule. All integer.
#include <stdio.h>
#include <stdlib.h>

#define P 1000000007L

static long lcg_next(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }

static void swap(long *a, int i, int j) { long t = a[i]; a[i] = a[j]; a[j] = t; }

// median-of-three + Hoare partition, recurse both sides; depth stays ~log N.
static void qsort_h(long *a, int lo, int hi) {
    if (lo >= hi) return;
    int mid = lo + (hi - lo) / 2;
    if (a[mid] < a[lo]) swap(a, lo, mid);
    if (a[hi]  < a[lo]) swap(a, lo, hi);
    if (a[hi]  < a[mid]) swap(a, mid, hi);
    long pivot = a[mid];
    int i = lo - 1, j = hi + 1;
    for (;;) {
        do i++; while (a[i] < pivot);
        do j--; while (a[j] > pivot);
        if (i >= j) break;
        swap(a, i, j);
    }
    qsort_h(a, lo, j);
    qsort_h(a, j + 1, hi);
}

static int bsearch_i(const long *a, int n, long key) {
    int lo = 0, hi = n - 1;
    while (lo <= hi) {
        int mid = lo + (hi - lo) / 2;
        if (a[mid] < key) lo = mid + 1;
        else if (a[mid] > key) hi = mid - 1;
        else return mid;
    }
    return -1;
}

int main(int argc, char **argv) {
    int N = argc > 1 ? atoi(argv[1]) : 100000;
    long *a = malloc((size_t)N * sizeof(long));
    long state = 42;
    for (int i = 0; i < N; i++) { state = lcg_next(state); a[i] = state; }
    qsort_h(a, 0, N - 1);
    long h = 0;
    for (int q = 0; q < N; q++) {
        state = lcg_next(state);
        long key = a[state % N];          // a value present in the sorted array -> a hit
        int idx = bsearch_i(a, N, key);
        h = (h * 31 + (idx + 1)) % P;
    }
    printf("%ld\n", h);
    printf("sort-search(%d)\n", N);
    free(a);
    return 0;
}
