// blur: a 2D image-convolution benchmark - the stencil axis of the suite. Generate a
// grayscale N x N image, then apply a 3x3 Gaussian blur kernel [1 2 1; 2 4 2; 1 2 1]/16
// PASSES times (double-buffered), with clamp (edge-replication) border handling, and reduce
// the result to a polynomial hash. All integer arithmetic - deterministic, no floating point.
#include <stdio.h>
#include <stdlib.h>

#define P 1000000007L
#define PASSES 4

static long lcg(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }
static int clampi(int x, int n) { return x < 0 ? 0 : (x >= n ? n - 1 : x); }

int main(int argc, char **argv) {
    int N = argc > 1 ? atoi(argv[1]) : 256;
    static const int K[9] = {1, 2, 1, 2, 4, 2, 1, 2, 1};   // 3x3, sum 16
    int *src = malloc((size_t)N * N * sizeof(int));
    int *dst = malloc((size_t)N * N * sizeof(int));
    long s = 42;
    for (long k = 0; k < (long)N * N; k++) { s = lcg(s); src[k] = (int)(s % 256); }
    for (int pass = 0; pass < PASSES; pass++) {
        for (int i = 0; i < N; i++) {
            for (int j = 0; j < N; j++) {
                int acc = 0;
                for (int di = -1; di <= 1; di++) {
                    int ni = clampi(i + di, N);
                    for (int dj = -1; dj <= 1; dj++) {
                        int nj = clampi(j + dj, N);
                        acc += K[(di + 1) * 3 + (dj + 1)] * src[(long)ni * N + nj];
                    }
                }
                dst[(long)i * N + j] = acc / 16;   // integer division
            }
        }
        int *t = src; src = dst; dst = t;          // double-buffer swap
    }
    long h = 0;
    for (long k = 0; k < (long)N * N; k++) h = (h * 31 + src[k]) % P;
    printf("%ld\n", h);
    printf("blur(%d)\n", N);
    return 0;
}
