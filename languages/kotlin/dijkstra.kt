// dijkstra: single-source shortest paths on a deterministically generated weighted
// digraph, using a HAND-WRITTEN binary min-heap (no stdlib priority queue). The graph
// axis of the suite - it stresses the heap + adjacency-list traversal + relaxation loop.
//
// The heap stores PACKED keys: key = dist * 2^21 + node. Comparing keys as plain integers
// is exactly the (dist, node) lexicographic order, and the keys are all UNIQUE (a node is
// only re-pushed when its distance strictly improves), so the heap behaviour - and thus the
// operation count - is identical in every language. The checksum is a hash of the final
// distance array, which is unique for Dijkstra regardless of heap internals. All integer.

const val P = 1000000007L
const val INF = 1L shl 62
const val DEG = 8            // average out-degree -> M = DEG*N directed edges
const val MAXW = 100         // edge weights 1..MAXW
const val BASE = 2097152L    // 2^21, larger than N; node packs into the low bits

fun lcg(s: Long): Long = (s * 1103515245L + 12345L) and 0x7fffffffL

// binary min-heap of packed long keys (all keys distinct)
lateinit var heap: LongArray
var hsize = 0

fun hpush(k: Long) {
    var i = hsize++
    heap[i] = k
    while (i > 0) {
        val p = (i - 1) / 2
        if (heap[p] <= heap[i]) break
        val t = heap[p]; heap[p] = heap[i]; heap[i] = t
        i = p
    }
}

fun hpop(): Long {
    val top = heap[0]
    heap[0] = heap[--hsize]
    var i = 0
    while (true) {
        val l = 2 * i + 1; val r = 2 * i + 2; var m = i
        if (l < hsize && heap[l] < heap[m]) m = l
        if (r < hsize && heap[r] < heap[m]) m = r
        if (m == i) break
        val t = heap[m]; heap[m] = heap[i]; heap[i] = t
        i = m
    }
    return top
}

fun dijkstra(n: Int): Long {
    val m = DEG.toLong() * n
    val eu = IntArray(m.toInt())
    val ev = IntArray(m.toInt())
    val ew = IntArray(m.toInt())
    var s = 42L
    for (e in 0 until m.toInt()) {
        s = lcg(s); eu[e] = (s % n).toInt()
        s = lcg(s); ev[e] = (s % n).toInt()
        s = lcg(s); ew[e] = (s % MAXW + 1).toInt()
    }
    // CSR adjacency in forward (edge-generation) order
    val start = LongArray(n + 1)
    for (e in 0 until m.toInt()) start[eu[e] + 1]++
    for (i in 0 until n) start[i + 1] += start[i]
    val cnt = LongArray(n)
    val adjV = IntArray(m.toInt())
    val adjW = IntArray(m.toInt())
    for (e in 0 until m.toInt()) {
        val pos = (start[eu[e]] + cnt[eu[e]]++).toInt()
        adjV[pos] = ev[e]; adjW[pos] = ew[e]
    }
    val dist = LongArray(n) { INF }
    dist[0] = 0
    heap = LongArray((m + 1).toInt())
    hsize = 0
    hpush(0L)
    while (hsize > 0) {
        val key = hpop()
        val d = key / BASE; val u = (key % BASE).toInt()
        if (d > dist[u]) continue            // stale heap entry
        for (e in start[u].toInt() until start[u + 1].toInt()) {
            val v = adjV[e]; val nd = d + adjW[e]
            if (nd < dist[v]) { dist[v] = nd; hpush(nd * BASE + v) }
        }
    }
    var h = 0L
    for (i in 0 until n) {
        val di = if (dist[i] < INF) dist[i] else 0L   // unreachable -> 0
        h = (h * 31 + di % P) % P
    }
    return h
}

fun main(args: Array<String>) {
    val n = if (args.isNotEmpty()) args[0].toInt() else 10000
    println(dijkstra(n))
    println("dijkstra($n)")
}
