// reverse-complement: generate a DNA sequence, reverse it in place while complementing
// each base (A<->T, C<->G), then reduce it to a polynomial string hash. The reverse uses a
// hand-written two-pointer loop (NOT a stdlib bulk reverse) and the hash a per-character
// loop (NOT a builtin), so this measures the language's own per-character processing -
// consistent with the suite's no-stdlib-shortcut rule. Everything is integer-deterministic.
using System;

class ReverseComplement
{
    const long P = 1000000007L;
    const long IM = 139968;
    const long IA = 3877;
    const long IC = 29573;

    static byte Comp(byte c)            // A<->T, C<->G; only A/C/G/T occur
    {
        return c == (byte)'A' ? (byte)'T'
             : c == (byte)'C' ? (byte)'G'
             : c == (byte)'G' ? (byte)'C'
             : (byte)'A';
    }

    static void Main(string[] args)
    {
        int L = args.Length > 0 ? int.Parse(args[0]) : 100000;
        byte[] s = new byte[L];
        long seed = 42;
        for (int i = 0; i < L; i++)
        {
            seed = (seed * IA + IC) % IM;
            s[i] = seed < 42000 ? (byte)'A'
                 : seed < 70000 ? (byte)'C'
                 : seed < 98000 ? (byte)'G'
                 : (byte)'T';
        }

        int lo = 0, hi = L - 1;
        while (lo < hi)                  // two-pointer reverse-and-complement, in place
        {
            byte a = Comp(s[lo]);
            s[lo] = Comp(s[hi]);
            s[hi] = a;
            lo++; hi--;
        }
        if (lo == hi) s[lo] = Comp(s[lo]);   // middle char when L is odd

        long h = 0;
        for (int k = 0; k < L; k++) h = (h * 31 + s[k]) % P;   // s[k] is the ASCII byte value

        Console.WriteLine(h);
        Console.WriteLine($"reverse-complement({L})");
    }
}
