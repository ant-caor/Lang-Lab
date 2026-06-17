// sort-search: generate N integers, sort them with a hand-written median-of-three
// quicksort (Hoare partition), then run N binary searches and fold the found indices
// into a checksum. The two classic algorithms - quicksort and binary search - written
// out explicitly (no stdlib sort/sort.Search), so this measures the LANGUAGE executing
// the SAME algorithm, consistent with the suite's no-stdlib-shortcut rule. All integer.
package main

import (
	"fmt"
	"os"
	"strconv"
)

const P int64 = 1000000007

func lcgNext(s int64) int64 { return (s*1103515245 + 12345) & 0x7fffffff }

// median-of-three + Hoare partition, recurse both sides; depth stays ~log N.
func qsortH(a []int64, lo, hi int) {
	if lo >= hi {
		return
	}
	mid := lo + (hi-lo)/2
	if a[mid] < a[lo] {
		a[lo], a[mid] = a[mid], a[lo]
	}
	if a[hi] < a[lo] {
		a[lo], a[hi] = a[hi], a[lo]
	}
	if a[hi] < a[mid] {
		a[mid], a[hi] = a[hi], a[mid]
	}
	pivot := a[mid]
	i, j := lo-1, hi+1
	for {
		i++
		for a[i] < pivot {
			i++
		}
		j--
		for a[j] > pivot {
			j--
		}
		if i >= j {
			break
		}
		a[i], a[j] = a[j], a[i]
	}
	qsortH(a, lo, j)
	qsortH(a, j+1, hi)
}

func bsearchI(a []int64, key int64) int {
	lo, hi := 0, len(a)-1
	for lo <= hi {
		mid := lo + (hi-lo)/2
		if a[mid] < key {
			lo = mid + 1
		} else if a[mid] > key {
			hi = mid - 1
		} else {
			return mid
		}
	}
	return -1
}

func run(n int) int64 {
	a := make([]int64, n)
	state := int64(42)
	for i := 0; i < n; i++ {
		state = lcgNext(state)
		a[i] = state
	}
	qsortH(a, 0, n-1)
	var h int64 = 0
	for q := 0; q < n; q++ {
		state = lcgNext(state)
		key := a[state%int64(n)] // a value present in the sorted array -> a hit
		idx := bsearchI(a, key)
		h = (h*31 + int64(idx+1)) % P
	}
	return h
}

func main() {
	n := 100000
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil {
			n = v
		}
	}
	fmt.Println(run(n))
	fmt.Printf("sort-search(%d)\n", n)
}
