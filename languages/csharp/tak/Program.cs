// tak: the Takeuchi function - the function-call / recursion-overhead axis of the suite.
// Naive recursive tak(x,y,z): three recursive calls per non-base node, NO memoization, NO
// iterative rewrite. It touches no arrays and allocates nothing - the ONLY thing it stresses
// is the cost of a function call + return + a couple of integer compares/decrements. The size
// n maps to the classic shape tak(3n, 2n, n).
//
// Checksum = the TOTAL number of calls (a strict invariant of doing the identical recursion;
// evaluation is eager so all three inner calls always run). Secondary = the returned value.
// All integer; values stay tiny (no overflow).
using System;

class Tak
{
    static long calls = 0;  // total entries to Tak; up to 2.5M at n=8 - 64-bit for headroom

    static int T(int x, int y, int z)
    {
        calls++;
        if (y < x) return T(T(x - 1, y, z), T(y - 1, z, x), T(z - 1, x, y));
        return z;
    }

    static void Main(string[] args)
    {
        int n = args.Length > 0 ? int.Parse(args[0]) : 6;
        int r = T(3 * n, 2 * n, n);
        Console.WriteLine(calls);
        Console.WriteLine($"tak({n}) = {r}");
    }
}
