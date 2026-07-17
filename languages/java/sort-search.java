// sort-search: generate N integers, sort them with a hand-written median-of-three
// quicksort (Hoare partition), then run N binary searches and fold the found indices
// into a checksum. The two classic algorithms - quicksort and binary search - written
// out explicitly (no stdlib sort/binarySearch), so this measures the LANGUAGE executing
// the SAME algorithm, consistent with the suite's no-stdlib-shortcut rule. All integer.

class SortSearch {
    static final long P = 1000000007L;

    static long lcgNext(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }

    static void swap(long[] a, int i, int j) {
        long t = a[i]; a[i] = a[j]; a[j] = t;
    }

    // median-of-three + Hoare partition, recurse both sides; depth stays ~log N.
    static void qsortH(long[] a, int lo, int hi) {
        if (lo >= hi) return;
        int mid = lo + (hi - lo) / 2;
        if (a[mid] < a[lo]) swap(a, lo, mid);
        if (a[hi] < a[lo]) swap(a, lo, hi);
        if (a[hi] < a[mid]) swap(a, mid, hi);
        long pivot = a[mid];
        int i = lo - 1;
        int j = hi + 1;
        while (true) {
            do { i++; } while (a[i] < pivot);
            do { j--; } while (a[j] > pivot);
            if (i >= j) break;
            swap(a, i, j);
        }
        qsortH(a, lo, j);
        qsortH(a, j + 1, hi);
    }

    static int bsearchI(long[] a, int n, long key) {
        int lo = 0, hi = n - 1;
        while (lo <= hi) {
            int mid = lo + (hi - lo) / 2;
            if (a[mid] < key) lo = mid + 1;
            else if (a[mid] > key) hi = mid - 1;
            else return mid;
        }
        return -1;
    }

    static long sortSearch(int n) {
        long[] a = new long[n];
        long state = 42L;
        for (int i = 0; i < n; i++) {
            state = lcgNext(state);
            a[i] = state;
        }
        qsortH(a, 0, n - 1);
        long h = 0L;
        for (int q = 0; q < n; q++) {
            state = lcgNext(state);
            long key = a[(int) (state % n)];   // a value present in the sorted array -> a hit
            int idx = bsearchI(a, n, key);
            h = (h * 31 + (idx + 1)) % P;
        }
        return h;
    }

    public static void main(String[] args) {
        int n = args.length > 0 ? Integer.parseInt(args[0]) : 100000;
        System.out.println(sortSearch(n));
        System.out.println("sort-search(" + n + ")");
    }
}
