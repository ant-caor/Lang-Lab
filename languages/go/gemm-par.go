// gemm-par: parallel quantized integer matrix-multiply.
// Invocation: gemm-par <cores> <n>
// Same algorithm and checksums as serial gemm; parallelises the outer i-loop
// by partitioning N output rows into `cores` contiguous bands.
// Loop order i,k,j (pinned, same as serial) within each band.
// No shared writes: each goroutine owns its slice of C.
package main

import (
	"fmt"
	"os"
	"runtime"
	"strconv"
	"sync"
	"time"
)

const P = 1000000007

func lcg(s int64) int64 { return (s*1103515245 + 12345) & 0x7fffffff }

func run(cores, n int) (int64, int64) {
	A := make([]int64, n*n)
	B := make([]int64, n*n)
	C := make([]int64, n*n)

	s := int64(42)
	for i := 0; i < n*n; i++ {
		s = lcg(s)
		A[i] = s % 128
	}
	for i := 0; i < n*n; i++ {
		s = lcg(s)
		B[i] = s % 128
	}

	// Partition rows [0,N) into `cores` contiguous bands.
	// Worker w handles rows [w*N/cores, (w+1)*N/cores).
	var wg sync.WaitGroup
	t0 := time.Now()
	wg.Add(cores)
	for w := 0; w < cores; w++ {
		w := w // capture loop variable
		rowStart := w * n / cores
		rowEnd := (w + 1) * n / cores
		go func() {
			defer wg.Done()
			for i := rowStart; i < rowEnd; i++ {
				for k := 0; k < n; k++ {
					a := A[i*n+k]
					kn := k * n
					base := i * n
					for j := 0; j < n; j++ {
						C[base+j] += a * B[kn+j]
					}
				}
			}
		}()
	}
	wg.Wait()
	fmt.Fprintf(os.Stderr, "COMPUTE_NS %d\n", time.Since(t0).Nanoseconds())

	var h int64 = 0
	for i := 0; i < n*n; i++ {
		h = (h*31 + C[i]%P) % P
	}
	return h, C[n*n-1] % P
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
	h, sec := run(cores, n)
	fmt.Println(h)
	fmt.Printf("gemm(%d) = %d\n", n, sec)
}
