// gbdt-par: parallel gradient-boosted decision-tree ensemble inference.
// Invocation: gbdt-par <cores> <n>
// Same algorithm and checksum as serial gbdt; parallelises the N-sample inference
// loop by partitioning samples into `cores` contiguous bands. Each goroutine
// traverses all B trees for its own samples and stores the per-sample acc value
// in a shared acc[] array (disjoint writes — no contention). After all goroutines
// join, the main thread computes h and total in a single serial pass over acc[]
// in index order, identical to the serial benchmark.
// Tree arrays (feat, thr, leafval) and sample[] are read-only and shared.
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
	P         = 1000000007
	D         = 8
	B         = 200
	F         = 8
	NODES     = 511 // 2^(D+1) - 1
	LEAFSTART = 255 // 2^D - 1
)

func lcg(s int64) int64 { return (s*1103515245 + 12345) & 0x7fffffff }

func run(cores, n int) (int64, int64) {
	feat := make([]int32, B*NODES)
	thr := make([]int32, B*NODES)
	leafval := make([]int32, B*NODES)

	s := int64(42)
	for b := 0; b < B; b++ {
		base := b * NODES
		for node := 0; node < LEAFSTART; node++ {
			s = lcg(s)
			feat[base+node] = int32(s % F)
			s = lcg(s)
			thr[base+node] = int32(s % 256)
		}
		for node := LEAFSTART; node < NODES; node++ {
			s = lcg(s)
			leafval[base+node] = int32(s % 10)
		}
	}

	sample := make([]int32, n*F)
	for i := 0; i < n*F; i++ {
		s = lcg(s)
		sample[i] = int32(s % 256)
	}

	// acc[i] stores the tree-ensemble sum for sample i.
	// Goroutines write disjoint ranges; no synchronisation needed.
	acc := make([]int64, n)

	var wg sync.WaitGroup
	t0 := time.Now()
	wg.Add(cores)
	for w := 0; w < cores; w++ {
		w := w
		start := w * n / cores
		end := (w + 1) * n / cores
		go func() {
			defer wg.Done()
			for i := start; i < end; i++ {
				sbase := i * F
				var a int64
				for b := 0; b < B; b++ {
					tbase := b * NODES
					node := 0
					for d := 0; d < D; d++ {
						if sample[sbase+int(feat[tbase+node])] <= thr[tbase+node] {
							node = 2*node + 1
						} else {
							node = 2*node + 2
						}
					}
					a += int64(leafval[tbase+node])
				}
				acc[i] = a
			}
		}()
	}
	wg.Wait()
	fmt.Fprintf(os.Stderr, "COMPUTE_NS %d\n", time.Since(t0).Nanoseconds())

	// Serial checksum pass in index order — identical to serial benchmark.
	var h, total int64
	for i := 0; i < n; i++ {
		h = (h*31 + acc[i] + 1) % P
		total = (total + acc[i]) % P
	}
	return h, total
}

func main() {
	cores := 1
	n := 5000
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
	h, total := run(cores, n)
	fmt.Println(h)
	fmt.Printf("gbdt(%d) = %d\n", n, total)
}
