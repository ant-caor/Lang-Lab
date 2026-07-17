// dijkstra: single-source shortest paths on a deterministically generated weighted
// digraph, using a HAND-WRITTEN binary min-heap (no stdlib priority queue). The graph
// axis of the suite - it stresses the heap + adjacency-list traversal + relaxation loop.
//
// The heap stores PACKED keys: key = dist * 2^21 + node. Comparing keys as plain integers
// is exactly the (dist, node) lexicographic order, and the keys are all UNIQUE (a node is
// only re-pushed when its distance strictly improves), so the heap behaviour - and thus the
// operation count - is identical in every language. The checksum is a hash of the final
// distance array, which is unique for Dijkstra regardless of heap internals. All integer.

import java.util.Arrays;

class Dijkstra {
    static final long P = 1000000007L;
    static final long INF = 1L << 62;
    static final int DEG = 8;       // average out-degree -> M = DEG*N directed edges
    static final int MAXW = 100;    // edge weights 1..MAXW
    static final long BASE = 2097152L;   // 2^21, larger than N; node packs into the low bits

    static long[] heap;
    static int hsize = 0;

    static long lcg(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }

    static void hpush(long k) {
        int i = hsize++;
        heap[i] = k;
        while (i > 0) {
            int p = (i - 1) / 2;
            if (heap[p] <= heap[i]) break;
            long t = heap[p]; heap[p] = heap[i]; heap[i] = t;
            i = p;
        }
    }

    static long hpop() {
        long top = heap[0];
        heap[0] = heap[--hsize];
        int i = 0;
        while (true) {
            int l = 2 * i + 1, r = 2 * i + 2, m = i;
            if (l < hsize && heap[l] < heap[m]) m = l;
            if (r < hsize && heap[r] < heap[m]) m = r;
            if (m == i) break;
            long t = heap[m]; heap[m] = heap[i]; heap[i] = t;
            i = m;
        }
        return top;
    }

    static long dijkstra(int n) {
        int m = DEG * n;
        int[] eu = new int[m];
        int[] ev = new int[m];
        int[] ew = new int[m];
        long s = 42L;
        for (int e = 0; e < m; e++) {
            s = lcg(s); eu[e] = (int) (s % n);
            s = lcg(s); ev[e] = (int) (s % n);
            s = lcg(s); ew[e] = (int) (s % MAXW + 1);
        }
        // CSR adjacency in forward (edge-generation) order
        long[] start = new long[n + 1];
        for (int e = 0; e < m; e++) start[eu[e] + 1]++;
        for (int i = 0; i < n; i++) start[i + 1] += start[i];
        long[] cnt = new long[n];
        int[] adjV = new int[m];
        int[] adjW = new int[m];
        for (int e = 0; e < m; e++) {
            int pos = (int) (start[eu[e]] + cnt[eu[e]]++);
            adjV[pos] = ev[e]; adjW[pos] = ew[e];
        }
        long[] dist = new long[n];
        Arrays.fill(dist, INF);
        dist[0] = 0;
        heap = new long[m + 1];
        hsize = 0;
        hpush(0L);
        while (hsize > 0) {
            long key = hpop();
            long d = key / BASE;
            int u = (int) (key % BASE);
            if (d > dist[u]) continue;   // stale heap entry
            for (int e = (int) start[u]; e < (int) start[u + 1]; e++) {
                int v = adjV[e];
                long nd = d + adjW[e];
                if (nd < dist[v]) { dist[v] = nd; hpush(nd * BASE + v); }
            }
        }
        long h = 0L;
        for (int i = 0; i < n; i++) {
            long di = dist[i] < INF ? dist[i] : 0L;   // unreachable -> 0
            h = (h * 31 + di % P) % P;
        }
        return h;
    }

    public static void main(String[] args) {
        int n = args.length > 0 ? Integer.parseInt(args[0]) : 10000;
        System.out.println(dijkstra(n));
        System.out.println("dijkstra(" + n + ")");
    }
}
