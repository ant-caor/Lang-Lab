// gbdt: gradient-boosted decision-tree ensemble inference — the dominant tabular-ML
// algorithm (XGBoost/LightGBM/CatBoost style). B=200 trees of depth D=8 over F=8
// features. Each tree is a flat complete binary tree (NODES=511): internal nodes
// 0..254 store a (feature-index, threshold) split; leaves 255..510 store a value.
// Children of node k: left=2k+1, right=2k+2. Inference: for each sample, traverse
// all B trees (exactly D compare-and-branch steps each) and sum the leaf values.
// Checksum: poly-hash of (acc+1) per sample; secondary = sum of acc values mod P.
// LCG draw order pinned: feat then thr per internal node, leafval per leaf, samples.
// All integer — no float, no ML/tree library.
package main

import (
	"fmt"
	"os"
	"strconv"
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

func run(n int) (int64, int64) {
	feat    := make([]int32, B*NODES)
	thr     := make([]int32, B*NODES)
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

	var h, total int64
	for i := 0; i < n; i++ {
		sbase := i * F
		var acc int64
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
			acc += int64(leafval[tbase+node])
		}
		h     = (h*31 + acc + 1) % P
		total = (total + acc) % P
	}
	return h, total
}

func main() {
	n := 5000
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil {
			n = v
		}
	}
	h, total := run(n)
	fmt.Println(h)
	fmt.Printf("gbdt(%d) = %d\n", n, total)
}
