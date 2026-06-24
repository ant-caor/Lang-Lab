// blur-par: parallel (wall-clock scaling track) 3x3 Gaussian blur. Same result as
// serial blur.c for ANY core count. Invocation: blur-par <cores> <n>.
// Per-pass row-band decomposition: within each of PASSES double-buffered passes,
// worker w writes output rows [w*N/cores, (w+1)*N/cores) of dst, reading the
// read-only src buffer (including neighbour rows + clamped borders). The join is
// the pass barrier; then src/dst swap. Output is bit-identical to serial.
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <time.h>

static long long now_ns(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return (long long)t.tv_sec * 1000000000LL + t.tv_nsec; }

#define P 1000000007L
#define PASSES 4

static long lcg(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }
static int clampi(int x, int n) { return x < 0 ? 0 : (x >= n ? n - 1 : x); }

static const int Kk[9] = {1, 2, 1, 2, 4, 2, 1, 2, 1};
static int N;
static int *src, *dst;

typedef struct { int lo, hi; } Band;

static void *worker(void *arg) {
    Band *b = (Band *)arg;
    for (int i = b->lo; i < b->hi; i++) {
        for (int j = 0; j < N; j++) {
            int acc = 0;
            for (int di = -1; di <= 1; di++) {
                int ni = clampi(i + di, N);
                for (int dj = -1; dj <= 1; dj++) {
                    int nj = clampi(j + dj, N);
                    acc += Kk[(di + 1) * 3 + (dj + 1)] * src[(long)ni * N + nj];
                }
            }
            dst[(long)i * N + j] = acc / 16;
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

    src = malloc((size_t)N * N * sizeof(int));
    dst = malloc((size_t)N * N * sizeof(int));
    long s = 42;
    for (long k = 0; k < (long)N * N; k++) { s = lcg(s); src[k] = (int)(s % 256); }

    long long _t0 = now_ns();
    for (int pass = 0; pass < PASSES; pass++) {
        pthread_t th[256];
        Band bands[256];
        for (int w = 0; w < cores; w++) {
            bands[w].lo = (int)((long)w * N / cores);
            bands[w].hi = (int)((long)(w + 1) * N / cores);
            pthread_create(&th[w], NULL, worker, &bands[w]);
        }
        for (int w = 0; w < cores; w++) pthread_join(th[w], NULL);
        int *t = src; src = dst; dst = t;   // barrier passed -> swap
    }
    fprintf(stderr, "COMPUTE_NS %lld\n", now_ns() - _t0);

    long h = 0;
    for (long k = 0; k < (long)N * N; k++) h = (h * 31 + src[k]) % P;
    printf("%ld\n", h);
    printf("blur(%d)\n", N);

    free(src); free(dst);
    return 0;
}
