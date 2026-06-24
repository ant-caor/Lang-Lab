// gbdt-par: parallel (wall-clock scaling track) gbdt inference. Same result as
// serial gbdt.c for ANY core count. Invocation: gbdt-par <cores> <n>.
// Sample-band decomposition: the ensemble (read-only) is built serially with the
// pinned LCG; each worker traverses all B trees for its sample band and writes its
// own acc[i] (disjoint). The poly-hash + total are then computed in a single SERIAL
// pass over acc[0..N-1] (same sample order as serial) -> bit-identical checksum.
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <time.h>

static long long now_ns(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return (long long)t.tv_sec * 1000000000LL + t.tv_nsec; }

#define P          1000000007L
#define D          8
#define B          200
#define F          8
#define NODES      511
#define LEAF_START 255

static long lcg(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }

static int N;
static int *feat, *thr, *leafval, *sample;
static long *accArr;

typedef struct { int lo, hi; } Band;

static void *worker(void *arg) {
    Band *b = (Band *)arg;
    for (int i = b->lo; i < b->hi; i++) {
        int sbase = i * F;
        long acc = 0;
        for (int bb = 0; bb < B; bb++) {
            int tbase = bb * NODES;
            int node = 0;
            for (int d = 0; d < D; d++) {
                if (sample[sbase + feat[tbase + node]] <= thr[tbase + node])
                    node = 2 * node + 1;
                else
                    node = 2 * node + 2;
            }
            acc += leafval[tbase + node];
        }
        accArr[i] = acc;
    }
    return NULL;
}

int main(int argc, char **argv) {
    int cores = argc > 1 ? atoi(argv[1]) : 1;
    N = argc > 2 ? atoi(argv[2]) : 5000;
    if (cores < 1) cores = 1;
    if (cores > N) cores = N;
    if (cores > 256) cores = 256;

    feat    = malloc((size_t)B * NODES * sizeof(int));
    thr     = malloc((size_t)B * NODES * sizeof(int));
    leafval = malloc((size_t)B * NODES * sizeof(int));
    sample  = malloc((size_t)N * F * sizeof(int));
    accArr  = malloc((size_t)N * sizeof(long));

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
    for (int i = 0; i < N * F; i++) { s = lcg(s); sample[i] = (int)(s % 256); }

    long long _t0 = now_ns();
    pthread_t th[256];
    Band bands[256];
    for (int w = 0; w < cores; w++) {
        bands[w].lo = (int)((long)w * N / cores);
        bands[w].hi = (int)((long)(w + 1) * N / cores);
        pthread_create(&th[w], NULL, worker, &bands[w]);
    }
    for (int w = 0; w < cores; w++) pthread_join(th[w], NULL);
    fprintf(stderr, "COMPUTE_NS %lld\n", now_ns() - _t0);

    long h = 0, total = 0;
    for (int i = 0; i < N; i++) {
        h     = (h     * 31 + accArr[i] + 1) % P;
        total = (total + accArr[i])           % P;
    }

    printf("%ld\n", h);
    printf("gbdt(%d) = %ld\n", N, total);

    free(feat); free(thr); free(leafval); free(sample); free(accArr);
    return 0;
}
