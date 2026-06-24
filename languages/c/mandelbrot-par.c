// mandelbrot-par: parallel (wall-clock scaling track) mandelbrot. Same result as
// serial mandelbrot.c for ANY core count. Invocation: mandelbrot-par <cores> <n>.
// Row-band decomposition: worker w counts in-set pixels for image rows
// [w*N/cores, (w+1)*N/cores); the count is a commutative sum -> core-invariant.
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <time.h>

static long long now_ns(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return (long long)t.tv_sec * 1000000000LL + t.tv_nsec; }

static int N;

typedef struct { int lo, hi; long count; } Band;

static void *worker(void *arg) {
    Band *b = (Band *)arg;
    long count = 0;
    for (int y = b->lo; y < b->hi; y++) {
        double ci = 2.0 * y / N - 1.0;
        for (int x = 0; x < N; x++) {
            double cr = 2.0 * x / N - 1.5;
            double zr = 0.0, zi = 0.0, tr = 0.0, ti = 0.0;
            int i = 0;
            while (i < 50 && tr + ti <= 4.0) {
                double t = zr * zi;
                zi = t + t + ci;   // == 2*zr*zi + ci, FMA-proof
                zr = tr - ti + cr;
                tr = zr * zr;
                ti = zi * zi;
                i++;
            }
            if (tr + ti <= 4.0) count++;
        }
    }
    b->count = count;
    return NULL;
}

int main(int argc, char **argv) {
    int cores = argc > 1 ? atoi(argv[1]) : 1;
    N = argc > 2 ? atoi(argv[2]) : 128;
    if (cores < 1) cores = 1;
    if (cores > N) cores = N;
    if (cores > 256) cores = 256;

    long long _t0 = now_ns();
    pthread_t th[256];
    Band bands[256];
    for (int w = 0; w < cores; w++) {
        bands[w].lo = (int)((long)w * N / cores);
        bands[w].hi = (int)((long)(w + 1) * N / cores);
        bands[w].count = 0;
        pthread_create(&th[w], NULL, worker, &bands[w]);
    }
    long count = 0;
    for (int w = 0; w < cores; w++) { pthread_join(th[w], NULL); count += bands[w].count; }
    fprintf(stderr, "COMPUTE_NS %lld\n", now_ns() - _t0);

    printf("%ld\n", count);
    printf("mandelbrot(%d)\n", N);
    return 0;
}
