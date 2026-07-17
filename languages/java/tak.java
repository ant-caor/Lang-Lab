// tak: the Takeuchi function - the function-call / recursion-overhead axis of the suite.
// Naive recursive tak(x,y,z): three recursive calls per non-base node, NO memoization, NO
// iterative rewrite. It touches no arrays and allocates nothing - the ONLY thing it stresses
// is the cost of a function call + return + a couple of integer compares/decrements. That
// isolates a dimension nothing else measures (binary-trees recurses too, but is dominated by
// heap allocation). The size n maps to the classic shape tak(3n, 2n, n).
//
// Checksum = the TOTAL number of calls (every entry counted, before the base test); secondary =
// the returned value. All integer; values stay tiny (no overflow). The call count is the strict
// correctness invariant (eager evaluation means all three inner calls always run).

class Tak {
    // Class-level counter - incremented at every entry to tak, before the base-case test.
    static long calls = 0L;

    static int tak(int x, int y, int z) {
        calls++;
        if (y < x) return tak(tak(x - 1, y, z), tak(y - 1, z, x), tak(z - 1, x, y));
        return z;
    }

    public static void main(String[] args) {
        int n = args.length > 0 ? Integer.parseInt(args[0]) : 6;
        int r = tak(3 * n, 2 * n, n);
        System.out.println(calls);
        System.out.println("tak(" + n + ") = " + r);
    }
}
