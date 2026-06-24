// mandelbrot-par: parallel Mandelbrot set pixel counter.
// Invocation: mandelbrot-par <cores> <n>
// Same algorithm and checksum as serial mandelbrot; parallelises over image rows
// by partitioning the NxN grid into `cores` contiguous row-bands.
// Each goroutine counts in-set pixels for its band; after join the main thread
// sums the partial counts (the final checksum IS the total count).
// The FMA-contraction-proof formula (t=zr*zi; zi=t+t+ci) is preserved identically.
package main

import (
	"fmt"
	"os"
	"runtime"
	"strconv"
	"sync"
	"time"
)

func mandelBand(n, rowStart, rowEnd int) int64 {
	var count int64 = 0
	for y := rowStart; y < rowEnd; y++ {
		ci := 2.0*float64(y)/float64(n) - 1.0
		for x := 0; x < n; x++ {
			cr := 2.0*float64(x)/float64(n) - 1.5
			zr, zi, tr, ti := 0.0, 0.0, 0.0, 0.0
			i := 0
			for i < 50 && tr+ti <= 4.0 {
				t := zr * zi
				zi = t + t + ci // == 2*zr*zi + ci, FMA-proof
				zr = tr - ti + cr
				tr = zr * zr
				ti = zi * zi
				i++
			}
			if tr+ti <= 4.0 {
				count++ // never escaped -> in set
			}
		}
	}
	return count
}

func run(cores, n int) int64 {
	partial := make([]int64, cores)
	var wg sync.WaitGroup
	t0 := time.Now()
	wg.Add(cores)
	for w := 0; w < cores; w++ {
		w := w // capture loop variable
		rowStart := w * n / cores
		rowEnd := (w + 1) * n / cores
		go func() {
			defer wg.Done()
			partial[w] = mandelBand(n, rowStart, rowEnd)
		}()
	}
	wg.Wait()
	fmt.Fprintf(os.Stderr, "COMPUTE_NS %d\n", time.Since(t0).Nanoseconds())
	var total int64
	for _, c := range partial {
		total += c
	}
	return total
}

func main() {
	cores := 1
	n := 128
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
	fmt.Printf("mandelbrot(%d)\n", n)
}
