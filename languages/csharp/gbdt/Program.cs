// gbdt: gradient-boosted decision-tree ensemble inference — the dominant tabular-ML
// algorithm (XGBoost/LightGBM/CatBoost style). B=200 trees of depth D=8 over F=8
// features. Each tree is a flat complete binary tree (NODES=511): internal nodes
// 0..254 store a (feature-index, threshold) split; leaves 255..510 store a value.
// Children of node k: left=2k+1, right=2k+2. Inference: for each sample, traverse
// all B trees (exactly D compare-and-branch steps each) and sum the leaf values.
// Checksum: poly-hash of (acc+1) per sample; secondary = sum of acc values mod P.
// LCG draw order pinned: feat then thr per internal node, leafval per leaf, samples.
// All integer — no float, no ML/tree library.
using System;

class Gbdt
{
    const long P         = 1000000007L;
    const int  D         = 8;
    const int  B         = 200;
    const int  F         = 8;
    const int  NODES     = 511;  // 2^(D+1) - 1
    const int  LEAFSTART = 255;  // 2^D - 1

    static long Lcg(long s) => (s * 1103515245L + 12345L) & 0x7fffffffL;

    static (long h, long total) Run(int n)
    {
        int[] feat    = new int[B * NODES];
        int[] thr     = new int[B * NODES];
        int[] leafval = new int[B * NODES];

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

        int[] sample = new int[n * F];
        for (int i = 0; i < n * F; i++) { s = Lcg(s); sample[i] = (int)(s % 256); }

        long h = 0L, total = 0L;
        for (int i = 0; i < n; i++)
        {
            int sbase = i * F;
            long acc  = 0L;
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
                acc += leafval[bbase + node];
            }
            h     = (h * 31 + acc + 1) % P;
            total = (total + acc) % P;
        }
        return (h, total);
    }

    static void Main(string[] args)
    {
        int n = args.Length > 0 ? int.Parse(args[0]) : 5000;
        var (h, total) = Run(n);
        Console.WriteLine(h);
        Console.WriteLine($"gbdt({n}) = {total}");
    }
}
