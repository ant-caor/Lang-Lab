import sys

P = 1000000007
INF = 1 << 62
DEG = 8            # average out-degree -> M = DEG*N directed edges
MAXW = 100         # edge weights 1..MAXW
BASE = 2097152     # 2^21, larger than N; node packs into the low bits


def dijkstra(n):
    m = DEG * n
    # generate the weighted digraph with the pinned LCG, forward adjacency order
    adj = [[] for _ in range(n)]
    s = 42
    for _ in range(m):
        s = (s * 1103515245 + 12345) & 0x7fffffff
        u = s % n
        s = (s * 1103515245 + 12345) & 0x7fffffff
        v = s % n
        s = (s * 1103515245 + 12345) & 0x7fffffff
        w = s % MAXW + 1
        adj[u].append((v, w))

    dist = [INF] * n
    dist[0] = 0

    # hand-written binary min-heap of packed long keys (all keys distinct)
    heap = [0]                                   # pack(0, 0) = 0
    hsize = 1
    while hsize > 0:
        # extract-min: top, then move last to root and sift down
        key = heap[0]
        hsize -= 1
        heap[0] = heap[hsize]
        i = 0
        while True:
            l = 2 * i + 1
            r = 2 * i + 2
            mn = i
            if l < hsize and heap[l] < heap[mn]:
                mn = l
            if r < hsize and heap[r] < heap[mn]:
                mn = r
            if mn == i:
                break
            heap[mn], heap[i] = heap[i], heap[mn]
            i = mn

        d = key // BASE
        u = key % BASE
        if d > dist[u]:                          # stale heap entry
            continue
        for v, w in adj[u]:
            nd = d + w
            if nd < dist[v]:
                dist[v] = nd
                # push: append packed key, then sift up
                k = nd * BASE + v
                if hsize < len(heap):
                    heap[hsize] = k
                else:
                    heap.append(k)
                i = hsize
                hsize += 1
                while i > 0:
                    par = (i - 1) // 2
                    if heap[par] <= heap[i]:
                        break
                    heap[par], heap[i] = heap[i], heap[par]
                    i = par

    h = 0
    for i in range(n):
        di = dist[i] if dist[i] < INF else 0     # unreachable -> 0
        h = (h * 31 + di % P) % P
    return h


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 10000
    print(dijkstra(n))
    print("dijkstra(%d)" % n)
