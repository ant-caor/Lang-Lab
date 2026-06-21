// gemm: quantized integer matrix-multiply - the dominant ML inference kernel.
// Square matmul of side N (i.e. N x N matrices). Loop order i,k,j (pinned)
// so B is accessed row-sequentially. LCG fills A then B with values 0..127.
// Accumulator is 64-bit; checksum = poly-hash of C row-major mod 1e9+7.
// No BLAS / no library matmul - the explicit triple loop.
package main

import (
	"fmt"
	"os"
	"strconv"
)

const P = 1000000007

func lcg(s int64) int64 { return (s*1103515245 + 12345) & 0x7fffffff }

func run(n int) (int64, int64) {
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

	// Pinned loop order i, k, j - B read row-sequentially.
	for i := 0; i < n; i++ {
		for k := 0; k < n; k++ {
			a := A[i*n+k]
			kn := k * n
			base := i * n
			for j := 0; j < n; j++ {
				C[base+j] += a * B[kn+j]
			}
		}
	}

	var h int64 = 0
	for i := 0; i < n*n; i++ {
		h = (h*31 + C[i]%P) % P
	}
	return h, C[n*n-1] % P
}

func main() {
	n := 256
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil {
			n = v
		}
	}
	h, sec := run(n)
	fmt.Println(h)
	fmt.Printf("gemm(%d) = %d\n", n, sec)
}
