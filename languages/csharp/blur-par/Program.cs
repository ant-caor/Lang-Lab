// blur-par: parallel scaling-track variant of blur.
// Invocation: blur-par <cores> <n>
// Output: identical to serial blur for any core count (core-invariant).
//
// Decomposition: per pass, divide the NxN image into P horizontal bands.
// Worker w computes output rows [w*n/cores, (w+1)*n/cores) from the current
// input buffer (read-only, shared). After all workers join, buffers are swapped
// for the next pass. Clamp (edge-replication) is identical to serial.
// The final poly-hash runs serially over src[] in row-major order.
//
// Warmup: LL_WARMUP (default 5) timed-region repetitions before the measured
// run so Tier-1 JIT is fully applied before timing starts.
// State reset per warmup: src is restored from pristineSrc before each run;
// dst is re-zeroed (unnecessary but defensive).
using System;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;

class BlurPar
{
    const long P     = 1000000007L;
    const int  PASSES = 4;

    static int Clampi(int x, int n) => x < 0 ? 0 : (x >= n ? n - 1 : x);

    static long Run(int cores, int N, int warmup)
    {
        int[] K = { 1, 2, 1, 2, 4, 2, 1, 2, 1 };   // 3x3 Gaussian, sum=16

        int[] pristineSrc = new int[N * N];

        // LCG initialisation, identical to serial.
        long s = 42;
        for (long k = 0; k < (long)N * N; k++)
        {
            s = (s * 1103515245L + 12345L) & 0x7fffffffL;
            pristineSrc[k] = (int)(s % 256);
        }

        int[] src = new int[N * N];
        int[] dst = new int[N * N];

        // Row-band boundaries (computed once, reused every pass and every run).
        int[] rowStart = new int[cores];
        int[] rowEnd   = new int[cores];
        for (int w = 0; w < cores; w++)
        {
            rowStart[w] = w * N / cores;
            rowEnd[w]   = (w + 1) * N / cores;
        }

        Task[] tasks = new Task[cores];

        // RunOnce: execute all PASSES over src/dst (reference-swapped), return
        // the final src reference (after all swaps).  Caller must restore src
        // from pristineSrc before each call so the computation is identical.
        int[] RunOnce(int[] srcIn, int[] dstIn)
        {
            int[] curSrc = srcIn;
            int[] curDst = dstIn;
            for (int pass = 0; pass < PASSES; pass++)
            {
                int[] srcPass = curSrc;
                int[] dstPass = curDst;

                for (int w = 0; w < cores; w++)
                {
                    int ww = w;
                    tasks[ww] = Task.Run(() =>
                    {
                        int rStart = rowStart[ww];
                        int rEnd   = rowEnd[ww];
                        for (int i = rStart; i < rEnd; i++)
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
                                        acc += K[(di + 1) * 3 + (dj + 1)] * srcPass[ni * N + nj];
                                    }
                                }
                                dstPass[i * N + j] = acc / 16;
                            }
                        }
                    });
                }
                Task.WaitAll(tasks);

                int[] tmp = curSrc; curSrc = curDst; curDst = tmp;
            }
            return curSrc;   // points to the result after all swaps
        }

        // Warmup: restore src from pristine before each run, discard result.
        for (int rep = 0; rep < warmup; rep++)
        {
            Array.Copy(pristineSrc, src, N * N);
            Array.Clear(dst, 0, N * N);
            RunOnce(src, dst);
        }

        // Timed run: restore src from pristine one final time.
        Array.Copy(pristineSrc, src, N * N);
        Array.Clear(dst, 0, N * N);

        long t0 = Stopwatch.GetTimestamp();
        int[] finalSrc = RunOnce(src, dst);
        long ns = (long)((Stopwatch.GetTimestamp() - t0) * (1_000_000_000.0 / Stopwatch.Frequency));
        Console.Error.WriteLine($"COMPUTE_NS {ns}");

        // Serial checksum, identical iteration order to serial benchmark.
        long h = 0;
        for (long k = 0; k < (long)N * N; k++) h = (h * 31 + finalSrc[k]) % P;
        return h;
    }

    static void Main(string[] args)
    {
        int cores  = args.Length > 0 ? int.Parse(args[0]) : 1;
        int n      = args.Length > 1 ? int.Parse(args[1]) : 256;
        int warmup = int.TryParse(Environment.GetEnvironmentVariable("LL_WARMUP"), out var w) ? w : 5;
        ThreadPool.SetMinThreads(cores, cores);
        ThreadPool.SetMaxThreads(cores, cores);
        Console.WriteLine(Run(cores, n, warmup));
        Console.WriteLine($"blur({n})");
    }
}
