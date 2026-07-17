"use strict";

// dijkstra: Dijkstra shortest paths with a hand-written binary min-heap of packed keys
// (dist * 2^21 + node). See sort-search.js for why the LCG uses Math.imul.

const P = 1000000007;
const INF = Math.pow(2, 62);
const DEG = 8; // average out-degree -> M = DEG*N directed edges
const MAXW = 100; // edge weights 1..MAXW
const BASE = 2097152; // 2^21, larger than N; node packs into the low bits

function lcgNext(s) {
  return (Math.imul(s, 1103515245) + 12345) & 0x7fffffff;
}

function dijkstra(n) {
  const m = DEG * n;
  // generate the weighted digraph with the pinned LCG, forward adjacency order
  const adj = new Array(n);
  for (let i = 0; i < n; i++) adj[i] = [];
  let s = 42;
  for (let e = 0; e < m; e++) {
    s = lcgNext(s);
    const u = s % n;
    s = lcgNext(s);
    const v = s % n;
    s = lcgNext(s);
    const w = (s % MAXW) + 1;
    adj[u].push([v, w]);
  }

  const dist = new Array(n).fill(INF);
  dist[0] = 0;

  // hand-written binary min-heap of packed keys (all keys distinct)
  let heap = [0]; // pack(0, 0) = 0
  let hsize = 1;
  while (hsize > 0) {
    // extract-min: top, then move last to root and sift down
    const key = heap[0];
    hsize -= 1;
    heap[0] = heap[hsize];
    let i = 0;
    for (;;) {
      const l = 2 * i + 1;
      const r = 2 * i + 2;
      let mn = i;
      if (l < hsize && heap[l] < heap[mn]) mn = l;
      if (r < hsize && heap[r] < heap[mn]) mn = r;
      if (mn === i) break;
      const t = heap[mn]; heap[mn] = heap[i]; heap[i] = t;
      i = mn;
    }

    const d = Math.floor(key / BASE);
    const u = key % BASE;
    if (d > dist[u]) continue; // stale heap entry
    const edges = adj[u];
    for (let ei = 0; ei < edges.length; ei++) {
      const v = edges[ei][0];
      const w = edges[ei][1];
      const nd = d + w;
      if (nd < dist[v]) {
        dist[v] = nd;
        // push: append packed key, then sift up
        const k = nd * BASE + v;
        if (hsize < heap.length) heap[hsize] = k;
        else heap.push(k);
        let idx = hsize;
        hsize += 1;
        while (idx > 0) {
          const par = (idx - 1) >> 1;
          if (heap[par] <= heap[idx]) break;
          const t = heap[par]; heap[par] = heap[idx]; heap[idx] = t;
          idx = par;
        }
      }
    }
  }

  let h = 0;
  for (let i = 0; i < n; i++) {
    const di = dist[i] < INF ? dist[i] : 0; // unreachable -> 0
    h = (h * 31 + (di % P)) % P;
  }
  return h;
}

function main() {
  const n = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : 10000;
  console.log(dijkstra(n));
  console.log(`dijkstra(${n})`);
}

main();
