package main

import (
	"fmt"
	"os"
	"strconv"
)

func fannkuch(n int) (int, int) {
	perm1 := make([]int, n)
	perm := make([]int, n)
	count := make([]int, n)
	for i := range perm1 {
		perm1[i] = i
	}
	maxFlips := 0
	checksum := 0
	permIdx := 0
	r := n

	for {
		for r != 1 {
			count[r-1] = r
			r--
		}

		copy(perm, perm1)
		flips := 0
		for k := perm[0]; k != 0; k = perm[0] {
			for i, j := 0, k; i < j; i, j = i+1, j-1 {
				perm[i], perm[j] = perm[j], perm[i]
			}
			flips++
		}

		if flips > maxFlips {
			maxFlips = flips
		}
		if permIdx%2 == 0 {
			checksum += flips
		} else {
			checksum -= flips
		}

		// Generate the next permutation.
		for {
			if r == n {
				return maxFlips, checksum
			}
			first := perm1[0]
			copy(perm1[:r], perm1[1:r+1])
			perm1[r] = first
			count[r]--
			if count[r] > 0 {
				break
			}
			r++
		}
		permIdx++
	}
}

func main() {
	n := 7
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil {
			n = v
		}
	}
	maxFlips, checksum := fannkuch(n)
	fmt.Println(checksum)
	fmt.Printf("Pfannkuchen(%d) = %d\n", n, maxFlips)
}
