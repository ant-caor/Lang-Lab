// tak: the Takeuchi function - the function-call / recursion-overhead axis of the suite.
// Naive recursive tak(x,y,z): three recursive calls per non-base node, NO memoization, NO
// iterative rewrite. It touches no arrays and allocates nothing - the ONLY thing it stresses
// is the cost of a function call + return + a couple of integer compares/decrements. That
// isolates a dimension nothing else measures (binary-trees recurses too, but is dominated by
// heap allocation). The size n maps to the classic shape tak(3n, 2n, n).
//
// Checksum = the TOTAL number of calls (a strict invariant of doing the identical recursion;
// evaluation is eager in every language so all three inner calls always run). Secondary = the
// returned value. All integer; values stay tiny (no overflow).
package main

import (
	"fmt"
	"os"
	"strconv"
)

var calls int64

func tak(x, y, z int) int {
	calls++
	if y < x {
		return tak(tak(x-1, y, z), tak(y-1, z, x), tak(z-1, x, y))
	}
	return z
}

func main() {
	n := 6
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil {
			n = v
		}
	}
	r := tak(3*n, 2*n, n)
	fmt.Println(calls)
	fmt.Printf("tak(%d) = %d\n", n, r)
}
