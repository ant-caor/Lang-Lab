// k-means-par: parallel (wall-clock scaling track) Lloyd's clustering. Same result
// as serial k-means.c for ANY core count. Invocation: k-means-par <cores> <n>.
// The ASSIGNMENT step (the O(N*K*D) hot loop) is parallelised over point-bands:
// worker w computes assign[i] for points [w*N/cores, (w+1)*N/cores), reading the
// read-only centroids. The centroid UPDATE (ssum/cnt accumulation + floor-mean +
// empty-cluster-unchanged) runs SERIALLY after the join, exactly as serial. The
// strict-< lowest-index tie-break is preserved (each worker scans k=0..K-1 in order).
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <time.h>

static long long now_ns(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return (long long)t.tv_sec * 1000000000LL + t.tv_nsec; }

#define P 1000000007L
#define K 16
#define D 4
#define ITERS 10
#define RANGE 256

static long lcg(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }

static int N;
static long *pt;
static long cen[K * D];
static int *assign;

typedef struct { int lo, hi; } Band;

static void *assign_worker(void *arg) {
    Band *b = (Band *)arg;
    for (int i = b->lo; i < b->hi; i++) {
        int best = 0; long bd = -1;
        for (int k = 0; k < K; k++) {
            long dist = 0;
            for (int d = 0; d < D; d++) { long df = pt[(long)i * D + d] - cen[k * D + d]; dist += df * df; }
            if (bd < 0 || dist < bd) { bd = dist; best = k; }
        }
        assign[i] = best;
    }
    return NULL;
}

static void parallel_assign(int cores) {
    pthread_t th[256];
    Band bands[256];
    for (int w = 0; w < cores; w++) {
        bands[w].lo = (int)((long)w * N / cores);
        bands[w].hi = (int)((long)(w + 1) * N / cores);
        pthread_create(&th[w], NULL, assign_worker, &bands[w]);
    }
    for (int w = 0; w < cores; w++) pthread_join(th[w], NULL);
}

int main(int argc, char **argv) {
    int cores = argc > 1 ? atoi(argv[1]) : 1;
    N = argc > 2 ? atoi(argv[2]) : 8000;
    if (cores < 1) cores = 1;
    if (cores > N) cores = N;
    if (cores > 256) cores = 256;

    pt = malloc((size_t)N * D * sizeof(long));
    long s = 42;
    for (long i = 0; i < (long)N * D; i++) { s = lcg(s); pt[i] = s % RANGE; }
    for (int i = 0; i < K * D; i++) cen[i] = pt[i];   // initial centroids = first K points
    assign = malloc((size_t)N * sizeof(int));

    long long _t0 = now_ns();
    for (int iter = 0; iter < ITERS; iter++) {
        parallel_assign(cores);                       // parallel assignment
        long ssum[K * D] = {0}; long cnt[K] = {0};     // serial update (identical to serial)
        for (int i = 0; i < N; i++) {
            int k = assign[i]; cnt[k]++;
            for (int d = 0; d < D; d++) ssum[k * D + d] += pt[(long)i * D + d];
        }
        for (int k = 0; k < K; k++)
            if (cnt[k] > 0)
                for (int d = 0; d < D; d++) cen[k * D + d] = ssum[k * D + d] / cnt[k];
    }

    parallel_assign(cores);                            // final assignment with final centroids
    fprintf(stderr, "COMPUTE_NS %lld\n", now_ns() - _t0);

    long h = 0;
    for (int i = 0; i < K * D; i++) h = (h * 31 + cen[i]) % P;
    for (int i = 0; i < N; i++) h = (h * 31 + assign[i]) % P;
    printf("%ld\n", h);
    printf("k-means(%d)\n", N);

    free(pt); free(assign);
    return 0;
}
