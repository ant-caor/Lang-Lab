// gbdt: gradient-boosted decision-tree ensemble inference — the dominant tabular-ML
// algorithm (XGBoost/LightGBM/CatBoost style). B=200 trees of depth D=8 over F=8
// features. Each tree is a flat complete binary tree (NODES=511): internal nodes
// 0..254 store a (feature-index, threshold) split; leaves 255..510 store a value.
// Children of node k: left=2k+1, right=2k+2. Inference: for each sample, traverse
// all B trees (exactly D compare-and-branch steps each) and sum the leaf values.
// Checksum: poly-hash of (acc+1) per sample; secondary = sum of acc values mod P.
// LCG draw order is pinned: feat then thr per internal node, leafval per leaf, then
// samples. All integer — no float, no ML/tree library.
#include <stdio.h>
#include <stdlib.h>

#define P          1000000007L
#define D          8
#define B          200
#define F          8
#define NODES      511          /* 2^(D+1) - 1 */
#define LEAF_START 255          /* 2^D - 1       */

static long lcg(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }

int main(int argc, char **argv) {
    int N = argc > 1 ? atoi(argv[1]) : 5000;

    int *feat    = malloc((size_t)B * NODES * sizeof(int));
    int *thr     = malloc((size_t)B * NODES * sizeof(int));
    int *leafval = malloc((size_t)B * NODES * sizeof(int));
    int *sample  = malloc((size_t)N * F * sizeof(int));

    /* Build ensemble: for each tree, internal nodes (feat then thr), then leaves */
    long s = 42;
    for (int b = 0; b < B; b++) {
        int base = b * NODES;
        for (int node = 0; node < LEAF_START; node++) {
            s = lcg(s); feat[base + node] = (int)(s % F);
            s = lcg(s); thr [base + node] = (int)(s % 256);
        }
        for (int node = LEAF_START; node < NODES; node++) {
            s = lcg(s); leafval[base + node] = (int)(s % 10);
        }
    }

    /* Draw samples */
    for (int i = 0; i < N * F; i++) { s = lcg(s); sample[i] = (int)(s % 256); }

    /* Inference */
    long h = 0, total = 0;
    for (int i = 0; i < N; i++) {
        int sbase = i * F;
        long acc = 0;
        for (int b = 0; b < B; b++) {
            int tbase = b * NODES;
            int node = 0;
            for (int d = 0; d < D; d++) {
                if (sample[sbase + feat[tbase + node]] <= thr[tbase + node])
                    node = 2 * node + 1;
                else
                    node = 2 * node + 2;
            }
            acc += leafval[tbase + node];
        }
        h     = (h     * 31 + acc + 1) % P;
        total = (total + acc)           % P;
    }

    printf("%ld\n", h);
    printf("gbdt(%d) = %ld\n", N, total);

    free(feat); free(thr); free(leafval); free(sample);
    return 0;
}
