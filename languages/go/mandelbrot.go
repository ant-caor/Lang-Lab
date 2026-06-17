// Mandelbrot set over an N x N grid of the complex plane [-1.5, 0.5] x [-1.0, 1.0].
// A pixel is "in the set" if |z| stays <= 2 (i.e. zr^2+zi^2 <= 4) through 50 iterations
// of z := z^2 + c starting from z = 0. The checksum is the count of in-set pixels.
//
// IEEE-754 float64 throughout. The 2*zr*zi term is written as t+t (t = zr*zi) instead
// of 2.0*zr*zi so there is NO multiply-add pattern for the compiler to FMA-contract; t+t
// is bit-identical to 2.0*t. This keeps the result bit-exact across every language
// regardless of FMA, fast-math defaults, or auto-vectorization.
package main

import (
	"fmt"
	"os"
	"strconv"
)

func mandel(n int) int64 {
	var count int64 = 0
	for y := 0; y < n; y++ {
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

func main() {
	n := 128
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil {
			n = v
		}
	}
	fmt.Println(mandel(n))
	fmt.Printf("mandelbrot(%d)\n", n)
}
