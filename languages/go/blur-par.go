// blur-par: parallel 3x3 Gaussian blur, PASSES double-buffered passes.
// Invocation: blur-par <cores> <n>
// Same algorithm and checksum as serial blur; parallelises within each pass by
// partitioning the NxN output image into `cores` contiguous row-bands.
// Workers read the full input buffer (src) — read-only, no data race — and write
// only their own rows of the output buffer (dst). After each pass the buffers are
// swapped (main goroutine) before the next pass begins. Border clamping (edge-
// replication) is identical to the serial version.
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
	P      = 1000000007
	PASSES = 4
)

func lcg(s int64) int64 { return (s*1103515245 + 12345) & 0x7fffffff }

func clampi(x, n int) int {
	if x < 0 {
		return 0
	}
	if x >= n {
		return n - 1
	}
	return x
}

// blurBand writes rows [rowStart, rowEnd) of dst from the full src buffer.
func blurBand(src, dst []int32, n, rowStart, rowEnd int) {
	K := [9]int32{1, 2, 1, 2, 4, 2, 1, 2, 1} // 3x3 Gaussian, sum 16
	for i := rowStart; i < rowEnd; i++ {
		for j := 0; j < n; j++ {
			var acc int32 = 0
			for di := -1; di <= 1; di++ {
				ni := clampi(i+di, n)
				for dj := -1; dj <= 1; dj++ {
					nj := clampi(j+dj, n)
					acc += K[(di+1)*3+(dj+1)] * src[ni*n+nj]
				}
			}
			dst[i*n+j] = acc / 16 // integer floor division
		}
	}
}

func run(cores, n int) int64 {
	src := make([]int32, n*n)
	dst := make([]int32, n*n)
	s := int64(42)
	for k := 0; k < n*n; k++ {
		s = lcg(s)
		src[k] = int32(s % 256)
	}

	var wg sync.WaitGroup
	t0 := time.Now()
	for pass := 0; pass < PASSES; pass++ {
		wg.Add(cores)
		for w := 0; w < cores; w++ {
			w := w // capture
			rowStart := w * n / cores
			rowEnd := (w + 1) * n / cores
			// Capture src/dst by pointer value at loop time — they are
			// resliced each pass after the swap below.
			curSrc := src
			curDst := dst
			go func() {
				defer wg.Done()
				blurBand(curSrc, curDst, n, rowStart, rowEnd)
			}()
		}
		wg.Wait()
		src, dst = dst, src // double-buffer swap (same as serial)
	}
	fmt.Fprintf(os.Stderr, "COMPUTE_NS %d\n", time.Since(t0).Nanoseconds())

	var h int64 = 0
	for k := 0; k < n*n; k++ {
		h = (h*31 + int64(src[k])) % P
	}
	return h
}

func main() {
	cores := 1
	n := 256
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
	fmt.Printf("blur(%d)\n", n)
}
