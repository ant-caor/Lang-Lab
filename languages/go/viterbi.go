// viterbi: integer HMM sequence decoding — the classical max-plus trellis.
// S=8 states, ALPHA=4 symbols, T=size parameter. LCG (glibc-style, seed=42)
// draws trans[S*S], emit[S*ALPHA], obs[T] in that order. Forward pass is a
// loop-carried max-reduction (STRICT > tie-break: lowest i wins), followed by
// a pointer-chain backtrace. Checksum = poly-hash of (path[t]+1).
// Secondary = optimal total path score mod P. No HMM library; pure integer.
package main

import (
	"fmt"
	"os"
	"strconv"
)

const (
	S     = 8
	ALPHA = 4
	P     = 1000000007
)

func lcg(s int64) int64 { return (s*1103515245 + 12345) & 0x7fffffff }

func run(t int) (int64, int64) {
	// Draw order: trans[S*S], emit[S*ALPHA], obs[T]
	var trans [S * S]int64
	var emit [S * ALPHA]int64
	s := int64(42)
	for x := 0; x < S*S; x++ {
		s = lcg(s)
		trans[x] = s%100 + 1
	}
	for x := 0; x < S*ALPHA; x++ {
		s = lcg(s)
		emit[x] = s%100 + 1
	}
	obs := make([]int, t)
	for i := 0; i < t; i++ {
		s = lcg(s)
		obs[i] = int(s % ALPHA)
	}

	// Initialise t=0
	var vitA, vitB [S]int64
	for j := 0; j < S; j++ {
		vitA[j] = emit[j*ALPHA+obs[0]]
	}
	vitPrev, vitNext := &vitA, &vitB

	back := make([]int32, t*S)

	// Forward trellis t=1..T-1
	for ti := 1; ti < t; ti++ {
		for j := 0; j < S; j++ {
			var best int64 = -1
			bi := int32(0)
			e := emit[j*ALPHA+obs[ti]]
			for i := 0; i < S; i++ {
				sc := vitPrev[i] + trans[i*S+j] + e
				if sc > best { // STRICT > -> lowest i wins
					best = sc
					bi = int32(i)
				}
			}
			vitNext[j] = best
			back[ti*S+j] = bi
		}
		vitPrev, vitNext = vitNext, vitPrev
	}

	// Final state: STRICT > -> lowest j wins
	bf := 0
	for j := 1; j < S; j++ {
		if vitPrev[j] > vitPrev[bf] {
			bf = j
		}
	}

	// Backtrace
	path := make([]int32, t)
	path[t-1] = int32(bf)
	for ti := t - 2; ti >= 0; ti-- {
		path[ti] = back[(ti+1)*S+int(path[ti+1])]
	}

	// Checksum
	var h int64 = 0
	for ti := 0; ti < t; ti++ {
		h = (h*31 + int64(path[ti]) + 1) % P
	}
	secondary := vitPrev[bf] % P
	return h, secondary
}

func main() {
	t := 20000
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil {
			t = v
		}
	}
	h, sec := run(t)
	fmt.Println(h)
	fmt.Printf("viterbi(%d) = %d\n", t, sec)
}
