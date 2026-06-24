// gemm-par: parallel (wall-clock scaling track) version of gemm. Produces the SAME
// result as serial gemm.c for ANY core count, so it passes the same checksum.
// Invocation:  gemm-par <cores> <n>
// Row-band decomposition: worker w computes output rows [w*N/cores, (w+1)*N/cores)
// with the SAME pinned i,k,j loop order as serial; each worker writes only its own
// rows of C (disjoint, no shared writes) -> result is bit-identical to serial.
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <time.h>

// COMPUTE_NS marker (to stderr): elapsed of the parallel compute region only, so the
// scaling track's speedup excludes data-gen + runtime startup. measure-scaling.sh reads it.
static long long now_ns(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return (long long)t.tv_sec * 1000000000LL + t.tv_nsec; }

#define P 1000000007L

static long lcg(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }

static int N;
static long *A, *B, *C;

typedef struct { int lo, hi; } Band;

static void *worker(void *arg) {
    Band *b = (Band *)arg;
    for (int i = b->lo; i < b->hi; i++) {
        for (int k = 0; k < N; k++) {
            long a = A[i * N + k];
            for (int j = 0; j < N; j++) {
                C[i * N + j] += a * B[k * N + j];
            }
        }
    }
    return NULL;
}

int main(int argc, char **argv) {
    int cores = argc > 1 ? atoi(argv[1]) : 1;
    N = argc > 2 ? atoi(argv[2]) : 256;
    if (cores < 1) cores = 1;
    if (cores > N) cores = N;
    if (cores > 256) cores = 256;

    A = malloc((size_t)N * N * sizeof(long));
    B = malloc((size_t)N * N * sizeof(long));
    C = calloc((size_t)N * N, sizeof(long));

    // Sequential init, identical LCG sequence to serial -> identical A, B, C.
    long s = 42;
    for (int i = 0; i < N * N; i++) { s = lcg(s); A[i] = s % 128; }
    for (int i = 0; i < N * N; i++) { s = lcg(s); B[i] = s % 128; }

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

    long h = 0;
    for (int i = 0; i < N * N; i++) h = (h * 31 + C[i] % P) % P;
    long secondary = C[N * N - 1] % P;
    printf("%ld\n", h);
    printf("gemm(%d) = %ld\n", N, secondary);

    free(A); free(B); free(C);
    return 0;
}
