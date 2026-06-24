// k-means-par: parallel Lloyd's k-means clustering.
// Invocation: k-means-par <cores> <n>
// Same algorithm and checksum as serial k-means; parallelises the ASSIGNMENT
// step of each iteration (and the final assignment pass) by partitioning the N
// points into `cores` contiguous bands. Each goroutine writes assign[i] for its
// own range of i — disjoint writes, no synchronisation needed on the array.
// The centroid UPDATE step (ssum accumulation + floor-mean) runs serially from
// the main goroutine after the barrier, identical to the serial version.
// Tie-break rule (strict <, lowest-index centroid wins) is preserved: workers
// scan k=0..K-1 in order and the partition is contiguous, so point order is
// unchanged.
package main

import (
	"fmt"
	"os"
	"runtime"
	"strconv"
	"sync"
	"time"
)

const (
	P     = 1000000007
	K     = 16
	D     = 4
	ITERS = 10
	RANGE = 256
)

func lcg(s int64) int64 { return (s*1103515245 + 12345) & 0x7fffffff }

// assignBand computes the nearest centroid for points [start, end) and writes
// results into assign[start..end). cen is read-only and shared.
func assignBand(pt, cen []int64, assign []int, start, end int) {
	for i := start; i < end; i++ {
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
}

func run(cores, n int) int64 {
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

	var wg sync.WaitGroup

	// parallelAssign runs the assignment step over all N points.
	parallelAssign := func() {
		wg.Add(cores)
		for w := 0; w < cores; w++ {
			w := w
			start := w * n / cores
			end := (w + 1) * n / cores
			go func() {
				defer wg.Done()
				assignBand(pt, cen, assign, start, end)
			}()
		}
		wg.Wait()
	}

	t0 := time.Now()
	for iter := 0; iter < ITERS; iter++ {
		parallelAssign()

		// Serial centroid update: floor-mean, empty cluster unchanged.
		ssum := make([]int64, K*D)
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

	// Final assignment pass with final centroids (same as serial).
	parallelAssign()
	fmt.Fprintf(os.Stderr, "COMPUTE_NS %d\n", time.Since(t0).Nanoseconds())

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
	cores := 1
	n := 8000
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil {
			cores = v
		}
	}
	if len(os.Args) > 2 {
		if v, err := strconv.Atoi(os.Args[2]); err == nil {
			n = v
		}
	}
	runtime.GOMAXPROCS(cores)
	fmt.Println(run(cores, n))
	fmt.Printf("k-means(%d)\n", n)
}
