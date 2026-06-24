// mandelbrot-par: parallel scaling-track variant of mandelbrot.
// Invocation: mandelbrot-par <cores> <n>
// Output: identical to serial mandelbrot for any core count (core-invariant).
//
// Decomposition: P horizontal row bands. Worker w handles rows
//   [w*n/cores, (w+1)*n/cores) (floor division, contiguous, disjoint).
// Each worker accumulates a private count; the main thread sums after Join.
// The FMA-contraction-proof formula (t = zr*zi; zi = t+t+ci) is preserved.
// Parallel.For with MaxDegreeOfParallelism=cores pins the thread count.
//
// Warmup: LL_WARMUP (default 5) timed-region repetitions before the measured
// run so Tier-1 JIT is complete and steady-state throughput is reported.
using System;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;

class MandelbrotPar
{
    // Compute the in-set pixel count for row y of an n x n grid.
    static int CountRow(int y, int n)
    {
        double ci = 2.0 * y / n - 1.0;
        int count = 0;
        for (int x = 0; x < n; x++)
        {
            double cr = 2.0 * x / n - 1.5;
            double zr = 0.0, zi = 0.0, tr = 0.0, ti = 0.0;
            int i = 0;
            while (i < 50 && tr + ti <= 4.0)
            {
                double t = zr * zi;
                zi = t + t + ci;   // 2*zr*zi+ci, FMA-proof
                zr = tr - ti + cr;
                tr = zr * zr;
                ti = zi * zi;
                i++;
            }
            if (tr + ti <= 4.0) count++;
        }
        return count;
    }

    // Run the parallel compute region once. workerCount must already be
    // allocated to length `cores`; it is fully overwritten by the workers.
    static long RunOnce(int cores, int n, long[] workerCount,
                        int[] rowStart, int[] rowEnd, Task[] tasks)
    {
        for (int w = 0; w < cores; w++)
        {
            int ww = w;
            tasks[ww] = Task.Run(() =>
            {
                long localCount = 0;
                for (int y = rowStart[ww]; y < rowEnd[ww]; y++)
                    localCount += CountRow(y, n);
                workerCount[ww] = localCount;
            });
        }
        Task.WaitAll(tasks);
        long total = 0;
        for (int w = 0; w < cores; w++) total += workerCount[w];
        return total;
    }

    static long Run(int cores, int n, int warmup)
    {
        long[] workerCount = new long[cores];

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
        // workerCount is fully overwritten each call, so no reset is needed.
        for (int rep = 0; rep < warmup; rep++)
            RunOnce(cores, n, workerCount, rowStart, rowEnd, tasks);

        // Timed run.
        long t0 = Stopwatch.GetTimestamp();
        long result = RunOnce(cores, n, workerCount, rowStart, rowEnd, tasks);
        long ns = (long)((Stopwatch.GetTimestamp() - t0) * (1_000_000_000.0 / Stopwatch.Frequency));
        Console.Error.WriteLine($"COMPUTE_NS {ns}");

        return result;
    }

    static void Main(string[] args)
    {
        int cores  = args.Length > 0 ? int.Parse(args[0]) : 1;
        int n      = args.Length > 1 ? int.Parse(args[1]) : 128;
        int warmup = int.TryParse(Environment.GetEnvironmentVariable("LL_WARMUP"), out var w) ? w : 5;
        // Limit ThreadPool so the degree of parallelism equals exactly `cores`.
        ThreadPool.SetMinThreads(cores, cores);
        ThreadPool.SetMaxThreads(cores, cores);
        Console.WriteLine(Run(cores, n, warmup));
        Console.WriteLine($"mandelbrot({n})");
    }
}
