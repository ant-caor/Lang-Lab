// dijkstra: single-source shortest paths on a deterministically generated weighted
// digraph, using a HAND-WRITTEN binary min-heap (no stdlib priority queue). The graph
// axis of the suite - it stresses the heap + adjacency-list traversal + relaxation loop.
//
// The heap stores PACKED keys: key = dist * 2^21 + node. Comparing keys as plain integers
// is exactly the (dist, node) lexicographic order, and the keys are all UNIQUE (a node is
// only re-pushed when its distance strictly improves), so the heap behaviour - and thus the
// operation count - is identical in every language. The checksum is a hash of the final
// distance array, which is unique for Dijkstra regardless of heap internals. All integer.
#include <stdio.h>
#include <stdlib.h>

#define P 1000000007L
#define INF (1L << 62)
#define DEG 8            // average out-degree -> M = DEG*N directed edges
#define MAXW 100         // edge weights 1..MAXW
#define BASE 2097152L    // 2^21, larger than N; node packs into the low bits

static long lcg(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }

// binary min-heap of packed long keys (all keys distinct)
static long *heap;
static long hsize;
static void hpush(long k) {
    long i = hsize++;
    heap[i] = k;
    while (i > 0) {
        long p = (i - 1) / 2;
        if (heap[p] <= heap[i]) break;
        long t = heap[p]; heap[p] = heap[i]; heap[i] = t;
        i = p;
    }
}
static long hpop(void) {
    long top = heap[0];
    heap[0] = heap[--hsize];
    long i = 0;
    for (;;) {
        long l = 2 * i + 1, r = 2 * i + 2, m = i;
        if (l < hsize && heap[l] < heap[m]) m = l;
        if (r < hsize && heap[r] < heap[m]) m = r;
        if (m == i) break;
        long t = heap[m]; heap[m] = heap[i]; heap[i] = t;
        i = m;
    }
    return top;
}

int main(int argc, char **argv) {
    int N = argc > 1 ? atoi(argv[1]) : 10000;
    long M = (long)DEG * N;
    int *eu = malloc(M * sizeof(int)), *ev = malloc(M * sizeof(int)), *ew = malloc(M * sizeof(int));
    long s = 42;
    for (long e = 0; e < M; e++) {
        s = lcg(s); eu[e] = s % N;
        s = lcg(s); ev[e] = s % N;
        s = lcg(s); ew[e] = s % MAXW + 1;
    }
    // CSR adjacency in forward (edge-generation) order
    long *start = calloc(N + 1, sizeof(long));
    for (long e = 0; e < M; e++) start[eu[e] + 1]++;
    for (int i = 0; i < N; i++) start[i + 1] += start[i];
    long *cnt = calloc(N, sizeof(long));
    int *adjV = malloc(M * sizeof(int)), *adjW = malloc(M * sizeof(int));
    for (long e = 0; e < M; e++) {
        long pos = start[eu[e]] + cnt[eu[e]]++;
        adjV[pos] = ev[e]; adjW[pos] = ew[e];
    }
    long *dist = malloc(N * sizeof(long));
    for (int i = 0; i < N; i++) dist[i] = INF;
    dist[0] = 0;
    heap = malloc((M + 1) * sizeof(long)); hsize = 0;
    hpush(0L);
    while (hsize > 0) {
        long key = hpop();
        long d = key / BASE, u = key % BASE;
        if (d > dist[u]) continue;            // stale heap entry
        for (long e = start[u]; e < start[u + 1]; e++) {
            long v = adjV[e], nd = d + adjW[e];
            if (nd < dist[v]) { dist[v] = nd; hpush(nd * BASE + v); }
        }
    }
    long h = 0;
    for (int i = 0; i < N; i++) {
        long di = dist[i] < INF ? dist[i] : 0;   // unreachable -> 0
        h = (h * 31 + di % P) % P;
    }
    printf("%ld\n", h);
    printf("dijkstra(%d)\n", N);
    return 0;
}
