package main

import (
	"fmt"
	"os"
	"strconv"
)

type Node struct {
	left, right *Node
}

func makeTree(depth int) *Node {
	if depth == 0 {
		return &Node{}
	}
	return &Node{makeTree(depth - 1), makeTree(depth - 1)}
}

func check(n *Node) int64 {
	if n.left == nil {
		return 1
	}
	return 1 + check(n.left) + check(n.right)
}

func run(n int) int64 {
	minDepth := 4
	maxDepth := minDepth + 2
	if n > maxDepth {
		maxDepth = n
	}
	stretchDepth := maxDepth + 1

	total := check(makeTree(stretchDepth))
	longLived := makeTree(maxDepth)

	depth := minDepth
	for depth <= maxDepth {
		iterations := 1 << (maxDepth - depth + minDepth)
		var s int64 = 0
		for i := 0; i < iterations; i++ {
			s += check(makeTree(depth))
		}
		total += s
		depth += 2
	}

	total += check(longLived)
	return total
}

func main() {
	n := 10
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil {
			n = v
		}
	}
	fmt.Println(run(n))
	fmt.Printf("binary-trees(%d)\n", n)
}
