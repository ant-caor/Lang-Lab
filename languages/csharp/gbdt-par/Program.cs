// gbdt-par: parallel scaling-track variant of gbdt.
// Invocation: gbdt-par <cores> <n>
// Output: identical to serial gbdt for any core count (core-invariant).
//
// Decomposition: divide N samples into P contiguous bands.
// Worker w processes samples [w*n/cores, (w+1)*n/cores): evaluates all B trees
// for each sample, writes acc[i] (disjoint per worker). Tree arrays feat[], thr[],
// leafval[] and sample[] are read-only and shared across workers.
// After all workers join, the main thread computes the serial checksum over
// acc[0..n-1] in index order — identical to the serial benchmark.
// LCG draw order for tree and sample initialisation is unchanged.
//
// Warmup: LL_WARMUP (default 5) timed-region repetitions before the measured
// run so Tier-1 JIT is fully applied before timing starts.
// State reset per warmup: acc[] is re-zeroed before each run (tree + sample
// arrays are read-only and never mutated).
using System;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;

class GbdtPar
{
    const long P         = 1000000007L;
    const int  D         = 8;
    const int  B         = 200;
    const int  F         = 8;
    const int  NODES     = 511;   // 2^(D+1) - 1
    const int  LEAFSTART = 255;   // 2^D - 1

    static long Lcg(long s) => (s * 1103515245L + 12345L) & 0x7fffffffL;

    static (long h, long total) Run(int cores, int n, int warmup)
    {
        int[] feat    = new int[B * NODES];
        int[] thr     = new int[B * NODES];
        int[] leafval = new int[B * NODES];

        // Tree initialisation: identical LCG draw order to serial benchmark.
        long s = 42L;
        for (int b = 0; b < B; b++)
        {
            int bbase = b * NODES;
            for (int node = 0; node < LEAFSTART; node++)
            {
                s = Lcg(s); feat[bbase + node] = (int)(s % F);
                s = Lcg(s); thr [bbase + node] = (int)(s % 256);
            }
            for (int node = LEAFSTART; node < NODES; node++)
            {
                s = Lcg(s); leafval[bbase + node] = (int)(s % 10);
            }
        }

        // Sample initialisation: identical LCG draw order to serial benchmark.
        int[] sample = new int[n * F];
        for (int i = 0; i < n * F; i++) { s = Lcg(s); sample[i] = (int)(s % 256); }

        // Per-sample accumulated leaf sum; exactly one worker writes each element.
        long[] acc = new long[n];

        // Row-band boundaries (floor division, contiguous, cover all n samples).
        int[] rowStart = new int[cores];
        int[] rowEnd   = new int[cores];
        for (int w = 0; w < cores; w++)
        {
            rowStart[w] = w * n / cores;
            rowEnd[w]   = (w + 1) * n / cores;
        }

        Task[] tasks = new Task[cores];

        // Inline helper: run the parallel compute region once over acc[].
        // Caller must zero acc[] before each call if a deterministic result is needed.
        void RunOnce()
        {
            for (int w = 0; w < cores; w++)
            {
                int ww = w;
                tasks[ww] = Task.Run(() =>
                {
                    for (int i = rowStart[ww]; i < rowEnd[ww]; i++)
                    {
                        int  sbase    = i * F;
                        long localAcc = 0L;
                        for (int b = 0; b < B; b++)
                        {
                            int bbase = b * NODES;
                            int node  = 0;
                            for (int d = 0; d < D; d++)
                            {
                                node = sample[sbase + feat[bbase + node]] <= thr[bbase + node]
                                    ? 2 * node + 1
                                    : 2 * node + 2;
                            }
                            localAcc += leafval[bbase + node];
                        }
                        acc[i] = localAcc;
                    }
                });
            }
            Task.WaitAll(tasks);
        }

        // Warmup: re-zero acc[] before each run, discard result.
        for (int rep = 0; rep < warmup; rep++)
        {
            Array.Clear(acc, 0, n);
            RunOnce();
        }

        // Timed run.
        Array.Clear(acc, 0, n);
        long t0 = Stopwatch.GetTimestamp();
        RunOnce();
        long ns = (long)((Stopwatch.GetTimestamp() - t0) * (1_000_000_000.0 / Stopwatch.Frequency));
        Console.Error.WriteLine($"COMPUTE_NS {ns}");

        // Serial checksum pass in index order: identical to serial benchmark.
        long h = 0L, total = 0L;
        for (int i = 0; i < n; i++)
        {
            h     = (h * 31 + acc[i] + 1) % P;
            total = (total + acc[i]) % P;
        }
        return (h, total);
    }

    static void Main(string[] args)
    {
        int cores  = args.Length > 0 ? int.Parse(args[0]) : 1;
        int n      = args.Length > 1 ? int.Parse(args[1]) : 5000;
        int warmup = int.TryParse(Environment.GetEnvironmentVariable("LL_WARMUP"), out var w) ? w : 5;
        ThreadPool.SetMinThreads(cores, cores);
        ThreadPool.SetMaxThreads(cores, cores);
        var (h, total) = Run(cores, n, warmup);
        Console.WriteLine(h);
        Console.WriteLine($"gbdt({n}) = {total}");
    }
}
