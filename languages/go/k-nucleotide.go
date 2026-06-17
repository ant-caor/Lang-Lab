package main

import (
	"fmt"
	"os"
	"strconv"
)

const (
	K  = 8
	P  = 1000000007
	IM = 139968
	IA = 3877
	IC = 29573
)

func gen(n int) []byte {
	s := make([]byte, n)
	var seed int64 = 42
	for i := 0; i < n; i++ {
		seed = (seed*IA + IC) % IM
		switch {
		case seed < 42000:
			s[i] = 'A'
		case seed < 70000:
			s[i] = 'C'
		case seed < 98000:
			s[i] = 'G'
		default:
			s[i] = 'T'
		}
	}
	return s
}

func run(n int) int64 {
	s := gen(n)

	counts := make(map[string]int64)
	for i := 0; i+K <= n; i++ {
		kmer := string(s[i : i+K])
		counts[kmer]++
	}

	var acc int64 = 0
	for kmer, count := range counts {
		var e int64 = 0
		for j := 0; j < K; j++ {
			var code int64
			switch kmer[j] {
			case 'A':
				code = 0
			case 'C':
				code = 1
			case 'G':
				code = 2
			default:
				code = 3
			}
			e = e*4 + code
		}
		acc = (acc + e*count) % P
	}
	return acc
}

func main() {
	n := 100000
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil {
			n = v
		}
	}
	fmt.Println(run(n))
	fmt.Printf("k-nucleotide(%d)\n", n)
}
