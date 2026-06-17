// sort-search: generate N integers, sort them with a hand-written median-of-three
// quicksort (Hoare partition), then run N binary searches and fold the found indices
// into a checksum. The two classic algorithms - quicksort and binary search - written
// out explicitly (no stdlib Array.Sort/Array.BinarySearch), so this measures the LANGUAGE
// executing the SAME algorithm, consistent with the suite's no-stdlib-shortcut rule.
// All integer.
using System;

class SortSearch
{
    const long P = 1000000007L;

    static long LcgNext(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }

    static void Swap(long[] a, int i, int j) { long t = a[i]; a[i] = a[j]; a[j] = t; }

    // median-of-three + Hoare partition, recurse both sides; depth stays ~log N.
    static void Qsort(long[] a, int lo, int hi)
    {
        if (lo >= hi) return;
        int mid = lo + (hi - lo) / 2;
        if (a[mid] < a[lo]) Swap(a, lo, mid);
        if (a[hi] < a[lo]) Swap(a, lo, hi);
        if (a[hi] < a[mid]) Swap(a, mid, hi);
        long pivot = a[mid];
        int i = lo - 1, j = hi + 1;
        for (;;)
        {
            do { i++; } while (a[i] < pivot);
            do { j--; } while (a[j] > pivot);
            if (i >= j) break;
            Swap(a, i, j);
        }
        Qsort(a, lo, j);
        Qsort(a, j + 1, hi);
    }

    static int Bsearch(long[] a, int n, long key)
    {
        int lo = 0, hi = n - 1;
        while (lo <= hi)
        {
            int mid = lo + (hi - lo) / 2;
            if (a[mid] < key) lo = mid + 1;
            else if (a[mid] > key) hi = mid - 1;
            else return mid;
        }
        return -1;
    }

    static void Main(string[] args)
    {
        int n = args.Length > 0 ? int.Parse(args[0]) : 100000;
        long[] a = new long[n];
        long state = 42;
        for (int i = 0; i < n; i++) { state = LcgNext(state); a[i] = state; }
        Qsort(a, 0, n - 1);
        long h = 0;
        for (int q = 0; q < n; q++)
        {
            state = LcgNext(state);
            long key = a[state % n];          // a value present in the sorted array -> a hit
            int idx = Bsearch(a, n, key);
            h = (h * 31 + (idx + 1)) % P;
        }
        Console.WriteLine(h);
        Console.WriteLine($"sort-search({n})");
    }
}
