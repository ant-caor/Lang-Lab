// gbdt: gradient-boosted decision-tree ensemble inference - the dominant tabular-ML
// algorithm (XGBoost/LightGBM/CatBoost style). B=200 trees of depth D=8 over F=8
// features. Each tree is a flat complete binary tree (NODES=511): internal nodes
// 0..254 store a (feature-index, threshold) split; leaves 255..510 store a value.
// Children of node k: left=2k+1, right=2k+2. Inference: for each sample, traverse
// all B trees (exactly D compare-and-branch steps each) and sum the leaf values.
// Checksum: poly-hash of (acc+1) per sample; secondary = sum of acc values mod P.
// LCG draw order pinned: feat then thr per internal node, leafval per leaf, samples.
// All integer - no float, no ML/tree library.

class Gbdt {
    static final long P = 1000000007L;
    static final int D = 8;
    static final int B = 200;
    static final int F = 8;
    static final int NODES = 511;        // 2^(D+1) - 1
    static final int LEAF_START = 255;   // 2^D - 1

    static long lcg(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }

    static long[] gbdt(int n) {
        int[] feat = new int[B * NODES];
        int[] thr = new int[B * NODES];
        int[] leafval = new int[B * NODES];

        long s = 42L;
        for (int b = 0; b < B; b++) {
            int base = b * NODES;
            for (int node = 0; node < LEAF_START; node++) {
                s = lcg(s); feat[base + node] = (int) (s % F);
                s = lcg(s); thr[base + node] = (int) (s % 256);
            }
            for (int node = LEAF_START; node < NODES; node++) {
                s = lcg(s); leafval[base + node] = (int) (s % 10);
            }
        }

        int[] sample = new int[n * F];
        for (int i = 0; i < n * F; i++) {
            s = lcg(s); sample[i] = (int) (s % 256);
        }

        long h = 0L;
        long total = 0L;
        for (int i = 0; i < n; i++) {
            int sbase = i * F;
            long acc = 0L;
            for (int b = 0; b < B; b++) {
                int tbase = b * NODES;
                int node = 0;
                for (int step = 0; step < D; step++) {
                    node = (sample[sbase + feat[tbase + node]] <= thr[tbase + node]) ? 2 * node + 1 : 2 * node + 2;
                }
                acc += leafval[tbase + node];
            }
            h = (h * 31 + acc + 1) % P;
            total = (total + acc) % P;
        }
        return new long[]{h, total};
    }

    public static void main(String[] args) {
        int n = args.length > 0 ? Integer.parseInt(args[0]) : 5000;
        long[] res = gbdt(n);
        System.out.println(res[0]);
        System.out.println("gbdt(" + n + ") = " + res[1]);
    }
}
