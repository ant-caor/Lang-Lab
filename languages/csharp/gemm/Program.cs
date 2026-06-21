// gemm: quantized integer matrix-multiply - the dominant ML inference kernel.
// Square matmul of side N (i.e. N x N matrices). Loop order i,k,j (pinned)
// so B is accessed row-sequentially. LCG fills A then B with values 0..127.
// Accumulator is 64-bit; checksum = poly-hash of C row-major mod 1e9+7.
// No BLAS / no library matmul - the explicit triple loop.
using System;

class Gemm
{
    const long P = 1000000007L;

    static long Lcg(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }

    static (long, long) Run(int n)
    {
        long[] A = new long[(long)n * n];
        long[] B = new long[(long)n * n];
        long[] C = new long[(long)n * n];

        long s = 42;
        for (long i = 0; i < (long)n * n; i++) { s = Lcg(s); A[i] = s % 128; }
        for (long i = 0; i < (long)n * n; i++) { s = Lcg(s); B[i] = s % 128; }

        // Pinned loop order i, k, j - B read row-sequentially.
        for (int i = 0; i < n; i++)
        {
            for (int k = 0; k < n; k++)
            {
                long a = A[(long)i * n + k];
                int kn = k * n;
                int base_ = i * n;
                for (int j = 0; j < n; j++)
                {
                    C[base_ + j] += a * B[kn + j];
                }
            }
        }

        long h = 0;
        for (long i = 0; i < (long)n * n; i++) h = (h * 31 + C[i] % P) % P;
        long secondary = C[(long)n * n - 1] % P;
        return (h, secondary);
    }

    static void Main(string[] args)
    {
        int n = args.Length > 0 ? int.Parse(args[0]) : 256;
        var (h, sec) = Run(n);
        Console.WriteLine(h);
        Console.WriteLine($"gemm({n}) = {sec}");
    }
}
