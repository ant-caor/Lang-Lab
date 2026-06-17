// k-means: Lloyd's clustering algorithm - the machine-learning axis of the suite. Cluster N
// integer D-dimensional points into K clusters over ITERS fixed iterations: assign each point
// to its nearest centroid (integer squared Euclidean distance), then recompute each centroid as
// the floor-mean of its members. Everything is integer (quantized-style) - deterministic, no
// floating point, so no FMA / summation-order divergence across languages.
//
// Pinned tie-breaks: a point ties to the LOWEST-index centroid (strict < while scanning); an
// empty cluster keeps its centroid unchanged. The checksum hashes the final centroids and the
// final assignment of every point.
using System;

class KMeans
{
    const long P = 1000000007L;
    const int K = 16;
    const int D = 4;
    const int ITERS = 10;
    const int RANGE = 256;

    static long Lcg(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }

    static long Run(int n)
    {
        long[] pt = new long[(long)n * D];
        long s = 42;
        for (long i = 0; i < (long)n * D; i++) { s = Lcg(s); pt[i] = s % RANGE; }
        long[] cen = new long[K * D];
        for (int i = 0; i < K * D; i++) cen[i] = pt[i];   // initial centroids = first K points
        int[] assign = new int[n];

        for (int iter = 0; iter < ITERS; iter++)
        {
            for (int i = 0; i < n; i++)                   // assignment
            {
                int best = 0; long bd = -1;
                for (int k = 0; k < K; k++)
                {
                    long dist = 0;
                    for (int d = 0; d < D; d++) { long df = pt[(long)i * D + d] - cen[k * D + d]; dist += df * df; }
                    if (bd < 0 || dist < bd) { bd = dist; best = k; }   // STRICT < : ties to lowest k
                }
                assign[i] = best;
            }
            long[] ssum = new long[K * D];                // update: floor-mean, empty unchanged
            long[] cnt = new long[K];
            for (int i = 0; i < n; i++)
            {
                int k = assign[i]; cnt[k]++;
                for (int d = 0; d < D; d++) ssum[k * D + d] += pt[(long)i * D + d];
            }
            for (int k = 0; k < K; k++)
                if (cnt[k] > 0)
                    for (int d = 0; d < D; d++) cen[k * D + d] = ssum[k * D + d] / cnt[k];   // integer (floor) division
        }

        for (int i = 0; i < n; i++)                       // final assignment with final centroids
        {
            int best = 0; long bd = -1;
            for (int k = 0; k < K; k++)
            {
                long dist = 0;
                for (int d = 0; d < D; d++) { long df = pt[(long)i * D + d] - cen[k * D + d]; dist += df * df; }
                if (bd < 0 || dist < bd) { bd = dist; best = k; }
            }
            assign[i] = best;
        }

        long h = 0;
        for (int i = 0; i < K * D; i++) h = (h * 31 + cen[i]) % P;
        for (int i = 0; i < n; i++) h = (h * 31 + assign[i]) % P;
        return h;
    }

    static void Main(string[] args)
    {
        int n = args.Length > 0 ? int.Parse(args[0]) : 8000;
        Console.WriteLine(Run(n));
        Console.WriteLine($"k-means({n})");
    }
}
