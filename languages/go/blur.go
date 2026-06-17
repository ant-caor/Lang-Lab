// blur: a 2D image-convolution benchmark - the stencil axis of the suite. Generate a
// grayscale N x N image, then apply a 3x3 Gaussian blur kernel [1 2 1; 2 4 2; 1 2 1]/16
// PASSES times (double-buffered), with clamp (edge-replication) border handling, and reduce
// the result to a polynomial hash. All integer arithmetic - deterministic, no floating point.
package main

import (
	"fmt"
	"os"
	"strconv"
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

func run(n int) int64 {
	K := [9]int32{1, 2, 1, 2, 4, 2, 1, 2, 1} // 3x3, sum 16
	src := make([]int32, n*n)
	dst := make([]int32, n*n)
	s := int64(42)
	for k := 0; k < n*n; k++ {
		s = lcg(s)
		src[k] = int32(s % 256)
	}
	for pass := 0; pass < PASSES; pass++ {
		for i := 0; i < n; i++ {
			for j := 0; j < n; j++ {
				var acc int32 = 0
				for di := -1; di <= 1; di++ {
					ni := clampi(i+di, n)
					for dj := -1; dj <= 1; dj++ {
						nj := clampi(j+dj, n)
						acc += K[(di+1)*3+(dj+1)] * src[ni*n+nj]
					}
				}
				dst[i*n+j] = acc / 16 // integer division
			}
		}
		src, dst = dst, src // double-buffer swap (refs, no copy)
	}
	var h int64 = 0
	for k := 0; k < n*n; k++ {
		h = (h*31 + int64(src[k])) % P
	}
	return h
}

func main() {
	n := 256
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil {
			n = v
		}
	}
	fmt.Println(run(n))
	fmt.Printf("blur(%d)\n", n)
}
