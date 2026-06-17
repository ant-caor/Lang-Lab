// blur: a 2D image-convolution benchmark - the stencil axis of the suite. Generate a
// grayscale N x N image, then apply a 3x3 Gaussian blur kernel [1 2 1; 2 4 2; 1 2 1]/16
// PASSES times (double-buffered), with clamp (edge-replication) border handling, and reduce
// the result to a polynomial hash. All integer arithmetic - deterministic, no floating point.
using System;

class Blur
{
    const long P = 1000000007L;
    const int PASSES = 4;

    static int Clampi(int x, int n) { return x < 0 ? 0 : (x >= n ? n - 1 : x); }

    static long Run(int N)
    {
        int[] K = { 1, 2, 1, 2, 4, 2, 1, 2, 1 };   // 3x3, sum 16
        int[] src = new int[N * N];
        int[] dst = new int[N * N];

        long s = 42;
        for (long k = 0; k < (long)N * N; k++)
        {
            s = (s * 1103515245L + 12345L) & 0x7fffffffL;
            src[k] = (int)(s % 256);
        }

        for (int pass = 0; pass < PASSES; pass++)
        {
            for (int i = 0; i < N; i++)
            {
                for (int j = 0; j < N; j++)
                {
                    int acc = 0;
                    for (int di = -1; di <= 1; di++)
                    {
                        int ni = Clampi(i + di, N);
                        for (int dj = -1; dj <= 1; dj++)
                        {
                            int nj = Clampi(j + dj, N);
                            acc += K[(di + 1) * 3 + (dj + 1)] * src[ni * N + nj];
                        }
                    }
                    dst[i * N + j] = acc / 16;   // integer division
                }
            }
            int[] t = src; src = dst; dst = t;   // double-buffer swap
        }

        long h = 0;
        for (long k = 0; k < (long)N * N; k++) h = (h * 31 + src[k]) % P;
        return h;
    }

    static void Main(string[] args)
    {
        int n = args.Length > 0 ? int.Parse(args[0]) : 256;
        Console.WriteLine(Run(n));
        Console.WriteLine($"blur({n})");
    }
}
