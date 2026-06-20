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
#include <stdio.h>
#include <stdlib.h>

static long calls = 0;

static int tak(int x, int y, int z) {
    calls++;
    if (y < x) return tak(tak(x - 1, y, z), tak(y - 1, z, x), tak(z - 1, x, y));
    return z;
}

int main(int argc, char **argv) {
    int n = argc > 1 ? atoi(argv[1]) : 6;
    int r = tak(3 * n, 2 * n, n);
    printf("%ld\n", calls);
    printf("tak(%d) = %d\n", n, r);
    return 0;
}
