// k-means: Lloyd's clustering algorithm - the machine-learning axis of the suite. Cluster N
// integer D-dimensional points into K clusters over ITERS fixed iterations: assign each point
// to its nearest centroid (integer squared Euclidean distance), then recompute each centroid as
// the floor-mean of its members. Everything is integer (quantized-style) - deterministic, no
// floating point, so no FMA / summation-order divergence across languages.
//
// Pinned tie-breaks: a point ties to the LOWEST-index centroid (strict < while scanning); an
// empty cluster keeps its centroid unchanged. The checksum hashes the final centroids and the
// final assignment of every point.
package main

import (
	"fmt"
	"os"
	"strconv"
)

const (
	P     = 1000000007
	K     = 16
	D     = 4
	ITERS = 10
	RANGE = 256
)

func lcg(s int64) int64 { return (s*1103515245 + 12345) & 0x7fffffff }

func run(n int) int64 {
	pt := make([]int64, n*D)
	s := int64(42)
	for i := 0; i < n*D; i++ {
		s = lcg(s)
		pt[i] = s % RANGE
	}
	cen := make([]int64, K*D)
	for i := 0; i < K*D; i++ {
		cen[i] = pt[i] // initial centroids = first K points
	}
	assign := make([]int, n)

	for iter := 0; iter < ITERS; iter++ {
		for i := 0; i < n; i++ { // assignment
			best := 0
			bd := int64(-1)
			for k := 0; k < K; k++ {
				var dist int64 = 0
				for d := 0; d < D; d++ {
					df := pt[i*D+d] - cen[k*D+d]
					dist += df * df
				}
				if bd < 0 || dist < bd {
					bd = dist
					best = k
				}
			}
			assign[i] = best
		}
		ssum := make([]int64, K*D) // update: floor-mean, empty unchanged
		cnt := make([]int64, K)
		for i := 0; i < n; i++ {
			k := assign[i]
			cnt[k]++
			for d := 0; d < D; d++ {
				ssum[k*D+d] += pt[i*D+d]
			}
		}
		for k := 0; k < K; k++ {
			if cnt[k] > 0 {
				for d := 0; d < D; d++ {
					cen[k*D+d] = ssum[k*D+d] / cnt[k]
				}
			}
		}
	}

	for i := 0; i < n; i++ { // final assignment with final centroids
		best := 0
		bd := int64(-1)
		for k := 0; k < K; k++ {
			var dist int64 = 0
			for d := 0; d < D; d++ {
				df := pt[i*D+d] - cen[k*D+d]
				dist += df * df
			}
			if bd < 0 || dist < bd {
				bd = dist
				best = k
			}
		}
		assign[i] = best
	}

	var h int64 = 0
	for i := 0; i < K*D; i++ {
		h = (h*31 + cen[i]) % P
	}
	for i := 0; i < n; i++ {
		h = (h*31 + int64(assign[i])) % P
	}
	return h
}

func main() {
	n := 8000
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil {
			n = v
		}
	}
	fmt.Println(run(n))
	fmt.Printf("k-means(%d)\n", n)
}
