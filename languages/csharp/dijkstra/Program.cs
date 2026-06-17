// dijkstra: single-source shortest paths on a deterministically generated weighted
// digraph, using a HAND-WRITTEN binary min-heap (no stdlib priority queue). The graph
// axis of the suite - it stresses the heap + adjacency-list traversal + relaxation loop.
//
// The heap stores PACKED keys: key = dist * 2^21 + node. Comparing keys as plain integers
// is exactly the (dist, node) lexicographic order, and the keys are all UNIQUE (a node is
// only re-pushed when its distance strictly improves), so the heap behaviour - and thus the
// operation count - is identical in every language. The checksum is a hash of the final
// distance array, which is unique for Dijkstra regardless of heap internals. All integer.
using System;

class Dijkstra
{
    const long P = 1000000007L;
    const long INF = 1L << 62;
    const int DEG = 8;            // average out-degree -> M = DEG*N directed edges
    const int MAXW = 100;         // edge weights 1..MAXW
    const long BASE = 2097152L;   // 2^21, larger than N; node packs into the low bits

    // hand-written binary min-heap of packed long keys (all keys distinct)
    static long[] heap;
    static int hsize;

    static void HPush(long k)
    {
        int i = hsize++;
        heap[i] = k;
        while (i > 0)
        {
            int p = (i - 1) / 2;
            if (heap[p] <= heap[i]) break;
            long t = heap[p]; heap[p] = heap[i]; heap[i] = t;
            i = p;
        }
    }

    static long HPop()
    {
        long top = heap[0];
        heap[0] = heap[--hsize];
        int i = 0;
        for (;;)
        {
            int l = 2 * i + 1, r = 2 * i + 2, m = i;
            if (l < hsize && heap[l] < heap[m]) m = l;
            if (r < hsize && heap[r] < heap[m]) m = r;
            if (m == i) break;
            long t = heap[m]; heap[m] = heap[i]; heap[i] = t;
            i = m;
        }
        return top;
    }

    static long Run(int n)
    {
        long m = (long)DEG * n;
        int[] eu = new int[m], ev = new int[m], ew = new int[m];
        long s = 42;
        for (long e = 0; e < m; e++)
        {
            s = (s * 1103515245L + 12345L) & 0x7fffffffL; eu[e] = (int)(s % n);
            s = (s * 1103515245L + 12345L) & 0x7fffffffL; ev[e] = (int)(s % n);
            s = (s * 1103515245L + 12345L) & 0x7fffffffL; ew[e] = (int)(s % MAXW + 1);
        }
        // CSR adjacency in forward (edge-generation) order
        long[] start = new long[n + 1];
        for (long e = 0; e < m; e++) start[eu[e] + 1]++;
        for (int i = 0; i < n; i++) start[i + 1] += start[i];
        long[] cnt = new long[n];
        int[] adjV = new int[m], adjW = new int[m];
        for (long e = 0; e < m; e++)
        {
            long pos = start[eu[e]] + cnt[eu[e]]++;
            adjV[pos] = ev[e]; adjW[pos] = ew[e];
        }
        long[] dist = new long[n];
        for (int i = 0; i < n; i++) dist[i] = INF;
        dist[0] = 0;
        heap = new long[m + 1]; hsize = 0;
        HPush(0L);
        while (hsize > 0)
        {
            long key = HPop();
            long d = key / BASE, u = key % BASE;
            if (d > dist[u]) continue;            // stale heap entry
            for (long e = start[u]; e < start[u + 1]; e++)
            {
                long v = adjV[e], nd = d + adjW[e];
                if (nd < dist[v]) { dist[v] = nd; HPush(nd * BASE + v); }
            }
        }
        long h = 0;
        for (int i = 0; i < n; i++)
        {
            long di = dist[i] < INF ? dist[i] : 0;   // unreachable -> 0
            h = (h * 31 + di % P) % P;
        }
        return h;
    }

    static void Main(string[] args)
    {
        int n = args.Length > 0 ? int.Parse(args[0]) : 10000;
        Console.WriteLine(Run(n));
        Console.WriteLine($"dijkstra({n})");
    }
}
