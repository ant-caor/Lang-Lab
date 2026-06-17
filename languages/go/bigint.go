// bigint: hand-rolled multi-precision arithmetic - the carry-propagation axis. Compute N! as an
// array of base-2^32 limbs by repeated bignum*smallint multiplication (each limb: cur = limb*k +
// carry; store low 32 bits, propagate the high bits), then poly-hash the limbs. Implemented by hand
// (NO native/library big integers - languages with built-in bignum must hand-roll too), so it
// measures raw multi-word arithmetic. All integer-deterministic.
package main

import (
	"fmt"
	"os"
	"strconv"
)

const P = 1000000007

func run(n int) int64 {
	limbs := make([]uint32, 1, n+64)
	limbs[0] = 1
	for k := uint64(2); k <= uint64(n); k++ {
		var carry uint64 = 0
		for i := 0; i < len(limbs); i++ {
			cur := uint64(limbs[i])*k + carry
			limbs[i] = uint32(cur & 0xFFFFFFFF)
			carry = cur >> 32
		}
		for carry > 0 {
			limbs = append(limbs, uint32(carry&0xFFFFFFFF))
			carry >>= 32
		}
	}
	var h int64 = 0
	for _, limb := range limbs {
		h = (h*31 + int64(limb)) % P
	}
	return h
}

func main() {
	n := 6000
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil {
			n = v
		}
	}
	fmt.Println(run(n))
	fmt.Printf("bigint(%d)\n", n)
}
