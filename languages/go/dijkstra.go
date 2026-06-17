// dijkstra: single-source shortest paths on a deterministically generated weighted
// digraph, using a HAND-WRITTEN binary min-heap (no stdlib priority queue). The graph
// axis of the suite - it stresses the heap + adjacency-list traversal + relaxation loop.
//
// The heap stores PACKED keys: key = dist * 2^21 + node. Comparing keys as plain integers
// is exactly the (dist, node) lexicographic order, and the keys are all UNIQUE (a node is
// only re-pushed when its distance strictly improves), so the heap behaviour - and thus the
// operation count - is identical in every language. The checksum is a hash of the final
// distance array, which is unique for Dijkstra regardless of heap internals. All integer.
package main

import (
	"fmt"
	"os"
	"strconv"
)

const (
	P    = 1000000007
	INF  = int64(1) << 62
	DEG  = 8       // average out-degree -> M = DEG*N directed edges
	MAXW = 100     // edge weights 1..MAXW
	BASE = 2097152 // 2^21, larger than N; node packs into the low bits
)

func lcg(s int64) int64 { return (s*1103515245 + 12345) & 0x7fffffff }

// binary min-heap of packed int64 keys (all keys distinct)
type heap struct {
	a    []int64
	size int
}

func (h *heap) push(k int64) {
	i := h.size
	h.size++
	h.a[i] = k
	for i > 0 {
		p := (i - 1) / 2
		if h.a[p] <= h.a[i] {
			break
		}
		h.a[p], h.a[i] = h.a[i], h.a[p]
		i = p
	}
}

func (h *heap) pop() int64 {
	top := h.a[0]
	h.size--
	h.a[0] = h.a[h.size]
	i := 0
	for {
		l, r, m := 2*i+1, 2*i+2, i
		if l < h.size && h.a[l] < h.a[m] {
			m = l
		}
		if r < h.size && h.a[r] < h.a[m] {
			m = r
		}
		if m == i {
			break
		}
		h.a[m], h.a[i] = h.a[i], h.a[m]
		i = m
	}
	return top
}

type edge struct {
	v int
	w int64
}

func dijkstra(n int) int64 {
	m := DEG * n
	// generate edges via the pinned LCG, build adjacency in forward (edge-generation) order
	adj := make([][]edge, n)
	s := int64(42)
	for e := 0; e < m; e++ {
		s = lcg(s)
		u := int(s % int64(n))
		s = lcg(s)
		v := int(s % int64(n))
		s = lcg(s)
		w := s%MAXW + 1
		adj[u] = append(adj[u], edge{v, w})
	}

	dist := make([]int64, n)
	for i := range dist {
		dist[i] = INF
	}
	dist[0] = 0

	h := &heap{a: make([]int64, m+1), size: 0}
	h.push(0)
	for h.size > 0 {
		key := h.pop()
		d := key / BASE
		u := int(key % BASE)
		if d > dist[u] { // stale heap entry
			continue
		}
		for _, e := range adj[u] {
			nd := d + e.w
			if nd < dist[e.v] {
				dist[e.v] = nd
				h.push(nd*BASE + int64(e.v))
			}
		}
	}

	var hash int64 = 0
	for i := 0; i < n; i++ {
		di := dist[i]
		if di >= INF { // unreachable -> 0
			di = 0
		}
		hash = (hash*31 + di%P) % P
	}
	return hash
}

func main() {
	n := 10000
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil {
			n = v
		}
	}
	fmt.Println(dijkstra(n))
	fmt.Printf("dijkstra(%d)\n", n)
}
