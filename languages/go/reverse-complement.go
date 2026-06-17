package main

import (
	"fmt"
	"os"
	"strconv"
)

const (
	P  int64 = 1000000007
	IM int64 = 139968
	IA int64 = 3877
	IC int64 = 29573
)

func comp(c byte) byte { // A<->T, C<->G; only A/C/G/T occur
	switch c {
	case 'A':
		return 'T'
	case 'C':
		return 'G'
	case 'G':
		return 'C'
	default:
		return 'A'
	}
}

func run(L int) int64 {
	s := make([]byte, L)
	seed := int64(42)
	for i := 0; i < L; i++ {
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

	i, j := 0, L-1
	for i < j { // two-pointer reverse-and-complement, in place
		a := comp(s[i])
		s[i] = comp(s[j])
		s[j] = a
		i++
		j--
	}
	if i == j { // middle char when L is odd
		s[i] = comp(s[i])
	}

	var h int64 = 0
	for k := 0; k < L; k++ {
		h = (h*31 + int64(s[k])) % P
	}
	return h
}

func main() {
	L := 100000
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil {
			L = v
		}
	}
	fmt.Println(run(L))
	fmt.Printf("reverse-complement(%d)\n", L)
}
