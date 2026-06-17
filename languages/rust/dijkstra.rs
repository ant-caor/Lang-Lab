// dijkstra: single-source shortest paths on a deterministically generated weighted
// digraph, using a HAND-WRITTEN binary min-heap (no stdlib priority queue). The graph
// axis of the suite - it stresses the heap + adjacency-list traversal + relaxation loop.
//
// The heap stores PACKED keys: key = dist * 2^21 + node. Comparing keys as plain integers
// is exactly the (dist, node) lexicographic order, and the keys are all UNIQUE (a node is
// only re-pushed when its distance strictly improves), so the heap behaviour - and thus the
// operation count - is identical in every language. The checksum is a hash of the final
// distance array, which is unique for Dijkstra regardless of heap internals. All integer.
use std::env;

const P: i64 = 1000000007;
const INF: i64 = 1i64 << 62;
const DEG: i64 = 8; // average out-degree -> M = DEG*N directed edges
const MAXW: i64 = 100; // edge weights 1..MAXW
const BASE: i64 = 2097152; // 2^21, larger than N; node packs into the low bits

fn lcg(s: i64) -> i64 {
    (s.wrapping_mul(1103515245).wrapping_add(12345)) & 0x7fffffff
}

// binary min-heap of packed i64 keys (all keys distinct)
struct Heap {
    a: Vec<i64>,
}

impl Heap {
    fn new(cap: usize) -> Heap {
        Heap { a: Vec::with_capacity(cap) }
    }

    fn push(&mut self, k: i64) {
        let mut i = self.a.len();
        self.a.push(k);
        while i > 0 {
            let p = (i - 1) / 2;
            if self.a[p] <= self.a[i] {
                break;
            }
            self.a.swap(p, i);
            i = p;
        }
    }

    fn pop(&mut self) -> i64 {
        let top = self.a[0];
        let last = self.a.pop().unwrap();
        let sz = self.a.len();
        if sz > 0 {
            self.a[0] = last;
            let mut i = 0;
            loop {
                let l = 2 * i + 1;
                let r = 2 * i + 2;
                let mut m = i;
                if l < sz && self.a[l] < self.a[m] {
                    m = l;
                }
                if r < sz && self.a[r] < self.a[m] {
                    m = r;
                }
                if m == i {
                    break;
                }
                self.a.swap(m, i);
                i = m;
            }
        }
        top
    }

    fn is_empty(&self) -> bool {
        self.a.is_empty()
    }
}

fn run(n: i64) -> i64 {
    let m = DEG * n;
    let mut eu = vec![0i64; m as usize];
    let mut ev = vec![0i64; m as usize];
    let mut ew = vec![0i64; m as usize];
    let mut s = 42i64;
    for e in 0..m as usize {
        s = lcg(s);
        eu[e] = s % n;
        s = lcg(s);
        ev[e] = s % n;
        s = lcg(s);
        ew[e] = s % MAXW + 1;
    }
    // adjacency in forward (edge-generation) order
    let mut adj: Vec<Vec<(i64, i64)>> = vec![Vec::new(); n as usize];
    for e in 0..m as usize {
        adj[eu[e] as usize].push((ev[e], ew[e]));
    }
    let mut dist = vec![INF; n as usize];
    dist[0] = 0;
    let mut heap = Heap::new((m + 1) as usize);
    heap.push(0);
    while !heap.is_empty() {
        let key = heap.pop();
        let d = key / BASE;
        let u = (key % BASE) as usize;
        if d > dist[u] {
            continue; // stale heap entry
        }
        for &(v, w) in &adj[u] {
            let nd = d + w;
            if nd < dist[v as usize] {
                dist[v as usize] = nd;
                heap.push(nd * BASE + v);
            }
        }
    }
    let mut h = 0i64;
    for i in 0..n as usize {
        let di = if dist[i] < INF { dist[i] } else { 0 }; // unreachable -> 0
        h = (h * 31 + di % P) % P;
    }
    h
}

fn main() {
    let n: i64 = env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(10000);
    println!("{}", run(n));
    println!("dijkstra({})", n);
}
