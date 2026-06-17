// dijkstra: single-source shortest paths on a deterministically generated weighted
// digraph, using a HAND-WRITTEN binary min-heap (no stdlib priority queue). The graph
// axis of the suite - it stresses the heap + adjacency-list traversal + relaxation loop.
//
// The heap stores PACKED keys: key = dist * 2^21 + node. Comparing keys as plain integers
// is exactly the (dist, node) lexicographic order, and the keys are all UNIQUE (a node is
// only re-pushed when its distance strictly improves), so the heap behaviour - and thus the
// operation count - is identical in every language. The checksum is a hash of the final
// distance array, which is unique for Dijkstra regardless of heap internals. All integer.
import Foundation

let P = 1000000007
let INF = 1 << 62
let DEG = 8            // average out-degree -> M = DEG*N directed edges
let MAXW = 100         // edge weights 1..MAXW
let BASE = 2097152     // 2^21, larger than N; node packs into the low bits

@inline(__always) func lcg(_ s: Int) -> Int {
    return (s &* 1103515245 &+ 12345) & 0x7fffffff
}

// binary min-heap of packed integer keys (all keys distinct)
var heap = [Int]()
var hsize = 0

@inline(__always) func hpush(_ k: Int) {
    var i = hsize
    if i < heap.count { heap[i] = k } else { heap.append(k) }
    hsize += 1
    while i > 0 {
        let p = (i - 1) / 2
        if heap[p] <= heap[i] { break }
        let t = heap[p]; heap[p] = heap[i]; heap[i] = t
        i = p
    }
}

@inline(__always) func hpop() -> Int {
    let top = heap[0]
    hsize -= 1
    heap[0] = heap[hsize]
    var i = 0
    while true {
        let l = 2 * i + 1, r = 2 * i + 2
        var m = i
        if l < hsize && heap[l] < heap[m] { m = l }
        if r < hsize && heap[r] < heap[m] { m = r }
        if m == i { break }
        let t = heap[m]; heap[m] = heap[i]; heap[i] = t
        i = m
    }
    return top
}

func dijkstra(_ N: Int) -> Int {
    let M = DEG * N
    var eu = [Int](repeating: 0, count: M)
    var ev = [Int](repeating: 0, count: M)
    var ew = [Int](repeating: 0, count: M)
    var s = 42
    for e in 0..<M {
        s = lcg(s); eu[e] = s % N
        s = lcg(s); ev[e] = s % N
        s = lcg(s); ew[e] = s % MAXW + 1
    }
    // CSR adjacency in forward (edge-generation) order
    var start = [Int](repeating: 0, count: N + 1)
    for e in 0..<M { start[eu[e] + 1] += 1 }
    for i in 0..<N { start[i + 1] += start[i] }
    var cnt = [Int](repeating: 0, count: N)
    var adjV = [Int](repeating: 0, count: M)
    var adjW = [Int](repeating: 0, count: M)
    for e in 0..<M {
        let pos = start[eu[e]] + cnt[eu[e]]
        cnt[eu[e]] += 1
        adjV[pos] = ev[e]; adjW[pos] = ew[e]
    }
    var dist = [Int](repeating: INF, count: N)
    dist[0] = 0
    heap = [Int](repeating: 0, count: M + 1)
    hsize = 0
    hpush(0)
    while hsize > 0 {
        let key = hpop()
        let d = key / BASE, u = key % BASE
        if d > dist[u] { continue }            // stale heap entry
        for e in start[u]..<start[u + 1] {
            let v = adjV[e], nd = d + adjW[e]
            if nd < dist[v] { dist[v] = nd; hpush(nd * BASE + v) }
        }
    }
    var h = 0
    for i in 0..<N {
        let di = dist[i] < INF ? dist[i] : 0   // unreachable -> 0
        h = (h * 31 + di % P) % P
    }
    return h
}

let N = CommandLine.arguments.count > 1 ? (Int(CommandLine.arguments[1]) ?? 10000) : 10000
print(dijkstra(N))
print("dijkstra(\(N))")
