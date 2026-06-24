// k-means-par: parallel scaling-track variant of k-means.
// Invocation: k-means-par <cores> <n>
// Output: identical to serial k-means for any core count (core-invariant).
//
// Decomposition (per iteration):
//   ASSIGNMENT (parallel): divide N points into P bands. Worker w assigns
//     points [w*n/cores, (w+1)*n/cores). Each worker writes only assign[i]
//     for its band; no two workers touch the same element. Tie-break: strict <,
//     lowest-index centroid wins — identical to serial (workers process points
//     in index order within their band, independent of other bands).
//   UPDATE (serial): the main thread merges the per-worker partial sums/counts
//     and recomputes centroids (floor-mean, empty cluster unchanged) — identical
//     arithmetic to the serial benchmark.
// Final assignment + checksum: serial, identical to serial benchmark.
//
// Warmup: LL_WARMUP (default 5) timed-region repetitions before the measured
// run so Tier-1 JIT is fully applied before timing starts.
// State reset per warmup: cen[] is restored to pt[0..K*D-1] (first K points)
// before each run; assign[] is zeroed (fully overwritten before checksum anyway).
using System;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;

class KMeansPar
{
    const long P     = 1000000007L;
    const int  K     = 16;
    const int  D     = 4;
    const int  ITERS = 10;
    const int  RANGE = 256;

    static long Lcg(long s) => (s * 1103515245L + 12345L) & 0x7fffffffL;

    // Assign point i (coordinates at pt[i*D .. i*D+D-1]) to nearest centroid.
    // Returns the centroid index with strict-< lowest-index tie-break.
    static int AssignPoint(long[] pt, long[] cen, int i)
    {
        int best = 0; long bd = -1;
        for (int k = 0; k < K; k++)
        {
            long dist = 0;
            for (int d = 0; d < D; d++)
            {
                long df = pt[(long)i * D + d] - cen[k * D + d];
                dist += df * df;
            }
            if (bd < 0 || dist < bd) { bd = dist; best = k; }
        }
        return best;
    }

    static long Run(int cores, int n, int warmup)
    {
        long[] pt = new long[(long)n * D];
        long s = 42;
        for (long i = 0; i < (long)n * D; i++) { s = Lcg(s); pt[i] = s % RANGE; }

        long[] cen    = new long[K * D];
        int[]  assign = new int[n];

        // Per-worker partial sums and counts, allocated once and reused.
        // Layout: [cores][K][D] for ssum, [cores][K] for cnt.
        long[][] wssum = new long[cores][];
        long[][] wcnt  = new long[cores][];
        for (int w = 0; w < cores; w++)
        {
            wssum[w] = new long[K * D];
            wcnt[w]  = new long[K];
        }

        int[] rowStart = new int[cores];
        int[] rowEnd   = new int[cores];
        for (int w = 0; w < cores; w++)
        {
            rowStart[w] = w * n / cores;
            rowEnd[w]   = (w + 1) * n / cores;
        }

        Task[] tasks = new Task[cores];

        // Inline helper: run one full Lloyd's pass (ITERS iterations) using the
        // current contents of cen[] as the starting centroids.
        void RunOnce()
        {
            for (int iter = 0; iter < ITERS; iter++)
            {
                // --- Parallel assignment + per-worker partial sums ---
                for (int w = 0; w < cores; w++)
                {
                    Array.Clear(wssum[w], 0, K * D);
                    Array.Clear(wcnt[w],  0, K);
                }

                long[] cenSnap = cen;

                for (int w = 0; w < cores; w++)
                {
                    int ww = w;
                    tasks[ww] = Task.Run(() =>
                    {
                        long[] ls = wssum[ww];
                        long[] lc = wcnt[ww];
                        for (int i = rowStart[ww]; i < rowEnd[ww]; i++)
                        {
                            int best = AssignPoint(pt, cenSnap, i);
                            assign[i] = best;
                            lc[best]++;
                            for (int d = 0; d < D; d++)
                                ls[best * D + d] += pt[(long)i * D + d];
                        }
                    });
                }
                Task.WaitAll(tasks);

                // --- Serial centroid update (merge partials, floor-mean) ---
                long[] ssum = new long[K * D];
                long[] cnt  = new long[K];
                for (int w = 0; w < cores; w++)
                {
                    for (int k = 0; k < K; k++)
                    {
                        cnt[k] += wcnt[w][k];
                        for (int d = 0; d < D; d++)
                            ssum[k * D + d] += wssum[w][k * D + d];
                    }
                }
                for (int k = 0; k < K; k++)
                    if (cnt[k] > 0)
                        for (int d = 0; d < D; d++)
                            cen[k * D + d] = ssum[k * D + d] / cnt[k];
            }
        }

        // Warmup: restore cen to first-K-points before each run, discard result.
        for (int rep = 0; rep < warmup; rep++)
        {
            Array.Copy(pt, cen, K * D);   // restore: cen[i] = pt[i] for i in [0, K*D)
            Array.Clear(assign, 0, n);
            RunOnce();
        }

        // Timed run: restore cen one final time.
        Array.Copy(pt, cen, K * D);
        Array.Clear(assign, 0, n);

        long t0 = Stopwatch.GetTimestamp();
        RunOnce();
        long ns = (long)((Stopwatch.GetTimestamp() - t0) * (1_000_000_000.0 / Stopwatch.Frequency));
        Console.Error.WriteLine($"COMPUTE_NS {ns}");

        // Final assignment with final centroids (serial, identical to serial benchmark).
        for (int i = 0; i < n; i++)
            assign[i] = AssignPoint(pt, cen, i);

        // Checksum (serial, identical order to serial benchmark).
        long h = 0;
        for (int i = 0; i < K * D; i++) h = (h * 31 + cen[i]) % P;
        for (int i = 0; i < n; i++) h = (h * 31 + assign[i]) % P;
        return h;
    }

    static void Main(string[] args)
    {
        int cores  = args.Length > 0 ? int.Parse(args[0]) : 1;
        int n      = args.Length > 1 ? int.Parse(args[1]) : 8000;
        int warmup = int.TryParse(Environment.GetEnvironmentVariable("LL_WARMUP"), out var w) ? w : 5;
        ThreadPool.SetMinThreads(cores, cores);
        ThreadPool.SetMaxThreads(cores, cores);
        Console.WriteLine(Run(cores, n, warmup));
        Console.WriteLine($"k-means({n})");
    }
}
