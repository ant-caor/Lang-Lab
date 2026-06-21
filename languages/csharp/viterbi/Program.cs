// viterbi: integer HMM sequence decoding — the classical max-plus trellis.
// S=8 states, ALPHA=4 symbols, T=size parameter. LCG (glibc-style, seed=42)
// draws trans[S*S], emit[S*ALPHA], obs[T] in that order. Forward pass is a
// loop-carried max-reduction (STRICT > tie-break: lowest i wins), followed by
// a pointer-chain backtrace. Checksum = poly-hash of (path[t]+1).
// Secondary = optimal total path score mod P. No HMM library; pure integer.
using System;

class Viterbi
{
    const int S     = 8;
    const int ALPHA = 4;
    const long P    = 1000000007L;

    static long Lcg(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }

    static (long, long) Run(int t)
    {
        // Draw order: trans[S*S], emit[S*ALPHA], obs[T]
        long[] trans = new long[S * S];
        long[] emit  = new long[S * ALPHA];
        int[]  obs   = new int[t];
        long s = 42L;
        for (int x = 0; x < S * S; x++)    { s = Lcg(s); trans[x] = s % 100 + 1; }
        for (int x = 0; x < S * ALPHA; x++) { s = Lcg(s); emit[x]  = s % 100 + 1; }
        for (int i = 0; i < t; i++)         { s = Lcg(s); obs[i] = (int)(s % ALPHA); }

        // Initialise t=0
        long[] vitPrev = new long[S];
        long[] vitNext = new long[S];
        for (int j = 0; j < S; j++) vitPrev[j] = emit[j * ALPHA + obs[0]];

        int[] back = new int[t * S];

        // Forward trellis t=1..T-1
        for (int ti = 1; ti < t; ti++)
        {
            for (int j = 0; j < S; j++)
            {
                long best = -1L; int bi = 0;
                long e = emit[j * ALPHA + obs[ti]];
                for (int i = 0; i < S; i++)
                {
                    long sc = vitPrev[i] + trans[i * S + j] + e;
                    if (sc > best) { best = sc; bi = i; }   // STRICT > -> lowest i wins
                }
                vitNext[j] = best;
                back[ti * S + j] = bi;
            }
            long[] tmp = vitPrev; vitPrev = vitNext; vitNext = tmp;
        }

        // Final state: STRICT > -> lowest j wins
        int bf = 0;
        for (int j = 1; j < S; j++) if (vitPrev[j] > vitPrev[bf]) bf = j;

        // Backtrace
        int[] path = new int[t];
        path[t - 1] = bf;
        for (int ti = t - 2; ti >= 0; ti--) path[ti] = back[(ti + 1) * S + path[ti + 1]];

        // Checksum
        long h = 0L;
        for (int ti = 0; ti < t; ti++) h = (h * 31L + path[ti] + 1L) % P;

        long secondary = vitPrev[bf] % P;
        return (h, secondary);
    }

    static void Main(string[] args)
    {
        int t = args.Length > 0 ? int.Parse(args[0]) : 20000;
        var (h, sec) = Run(t);
        Console.WriteLine(h);
        Console.WriteLine($"viterbi({t}) = {sec}");
    }
}
