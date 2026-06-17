// bigint: hand-rolled multi-precision arithmetic - the carry-propagation axis. Compute N! as an
// array of base-2^32 limbs by repeated bignum*smallint multiplication (each limb: cur = limb*k +
// carry; store low 32 bits, propagate the high bits), then poly-hash the limbs. Implemented by hand
// (NO native/library big integers - System.Numerics.BigInteger is NOT used), so it measures raw
// multi-word arithmetic. All integer-deterministic. P = 1000000007.
using System;

class BigInt
{
    const long P = 1000000007L;

    static long Run(int n)
    {
        // limbs: least-significant limb first, base 2^32. The big number IS this array.
        uint[] limbs = new uint[n + 64];
        int len = 1;
        limbs[0] = 1;

        for (long k = 2; k <= n; k++)
        {
            ulong carry = 0;
            for (int i = 0; i < len; i++)
            {
                ulong cur = (ulong)limbs[i] * (ulong)k + carry; // 64-bit intermediate (~2^46)
                limbs[i] = (uint)(cur & 0xFFFFFFFF);            // low 32 bits stay
                carry = cur >> 32;                              // high bits propagate
            }
            while (carry > 0)
            {
                limbs[len++] = (uint)(carry & 0xFFFFFFFF);
                carry >>= 32;
            }
        }

        long h = 0;
        for (int i = 0; i < len; i++) // poly-hash, least-significant limb first
            h = (h * 31 + limbs[i]) % P;
        return h;
    }

    static void Main(string[] args)
    {
        int n = args.Length > 0 ? int.Parse(args[0]) : 6000;
        Console.WriteLine(Run(n));
        Console.WriteLine($"bigint({n})");
    }
}
