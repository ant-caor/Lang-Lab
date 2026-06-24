// gemm-par: parallel scaling-track variant of gemm.
// Invocation: gemm-par <cores> <n>
// Output: identical to serial gemm for any core count (core-invariant).
//
// Decomposition: P horizontal row bands of the output matrix C.
// Worker w computes rows [w*n/cores, (w+1)*n/cores) (floor division,
// contiguous, disjoint). Loop order i->k->j is pinned (serial fairness rule).
// A and B are read-only and shared across workers. C rows are disjoint writes.
// The checksum runs serially after all workers join, row-major, identical to
// the serial benchmark.
//
// Warmup: LL_WARMUP (default 5) timed-region repetitions before the measured
// run so Tier-1 JIT is fully applied before timing starts. C is re-zeroed
// between warmup iterations so accumulation is not doubled across runs.
using System;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;

class GemmPar
{
    const long P = 1000000007L;

    static long Lcg(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }

    // Execute the parallel matmul once: zero C, launch workers, wait.
    // rowStart/rowEnd/tasks are pre-allocated by Run() and reused across warmup.
    static void RunOnce(int cores, int n, long[] A, long[] B, long[] C,
                        int[] rowStart, int[] rowEnd, Task[] tasks)
    {
        Array.Clear(C, 0, n * n);

        for (int w = 0; w < cores; w++)
        {
            int ww = w;
            tasks[ww] = Task.Run(() =>
            {
                int rStart = rowStart[ww];
                int rEnd   = rowEnd[ww];
                for (int i = rStart; i < rEnd; i++)
                {
                    for (int k = 0; k < n; k++)
                    {
                        long a = A[(long)i * n + k];
                        int kn    = k * n;
                        int baseI = i * n;
                        for (int j = 0; j < n; j++)
                        {
                            C[baseI + j] += a * B[kn + j];
                        }
                    }
                }
            });
        }
        Task.WaitAll(tasks);
    }

    static (long, long) Run(int cores, int n, int warmup)
    {
        long[] A = new long[(long)n * n];
        long[] B = new long[(long)n * n];
        long[] C = new long[(long)n * n];

        // LCG initialisation, identical to serial gemm.
        long s = 42;
        for (long i = 0; i < (long)n * n; i++) { s = Lcg(s); A[i] = s % 128; }
        for (long i = 0; i < (long)n * n; i++) { s = Lcg(s); B[i] = s % 128; }

        // Row-band boundaries (computed once, reused every run).
        int[] rowStart = new int[cores];
        int[] rowEnd   = new int[cores];
        for (int w = 0; w < cores; w++)
        {
            rowStart[w] = w * n / cores;
            rowEnd[w]   = (w + 1) * n / cores;
        }

        Task[] tasks = new Task[cores];

        // Warmup: run the parallel compute region `warmup` times, discarding
        // results, so that Tier-1 JIT is fully applied before timing starts.
        // RunOnce re-zeros C at the start of each call, preventing accumulation.
        for (int rep = 0; rep < warmup; rep++)
            RunOnce(cores, n, A, B, C, rowStart, rowEnd, tasks);

        // Timed run.
        long t0 = Stopwatch.GetTimestamp();
        RunOnce(cores, n, A, B, C, rowStart, rowEnd, tasks);
        long ns = (long)((Stopwatch.GetTimestamp() - t0) * (1_000_000_000.0 / Stopwatch.Frequency));
        Console.Error.WriteLine($"COMPUTE_NS {ns}");

        // Serial checksum, identical iteration order to serial benchmark.
        long h = 0;
        for (long i = 0; i < (long)n * n; i++) h = (h * 31 + C[i] % P) % P;
        long secondary = C[(long)n * n - 1] % P;
        return (h, secondary);
    }

    static void Main(string[] args)
    {
        int cores  = args.Length > 0 ? int.Parse(args[0]) : 1;
        int n      = args.Length > 1 ? int.Parse(args[1]) : 256;
        int warmup = int.TryParse(Environment.GetEnvironmentVariable("LL_WARMUP"), out var w) ? w : 5;
        // Limit ThreadPool so the degree of parallelism equals exactly `cores`.
        ThreadPool.SetMinThreads(cores, cores);
        ThreadPool.SetMaxThreads(cores, cores);
        var (h, sec) = Run(cores, n, warmup);
        Console.WriteLine(h);
        Console.WriteLine($"gemm({n}) = {sec}");
    }
}
