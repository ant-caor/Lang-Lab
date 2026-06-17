// k-means: Lloyd's clustering algorithm - the machine-learning axis of the suite. Cluster N
// integer D-dimensional points into K clusters over ITERS fixed iterations: assign each point
// to its nearest centroid (integer squared Euclidean distance), then recompute each centroid as
// the floor-mean of its members. Everything is integer (quantized-style) - deterministic, no
// floating point, so no FMA / summation-order divergence across languages.
//
// Pinned tie-breaks: a point ties to the LOWEST-index centroid (strict < while scanning); an
// empty cluster keeps its centroid unchanged. The checksum hashes the final centroids and the
// final assignment of every point.
#include <stdio.h>
#include <stdlib.h>

#define P 1000000007L
#define K 16
#define D 4
#define ITERS 10
#define RANGE 256

static long lcg(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }

int main(int argc, char **argv) {
    int N = argc > 1 ? atoi(argv[1]) : 8000;
    long *pt = malloc((size_t)N * D * sizeof(long));
    long s = 42;
    for (long i = 0; i < (long)N * D; i++) { s = lcg(s); pt[i] = s % RANGE; }
    long cen[K * D];
    for (int i = 0; i < K * D; i++) cen[i] = pt[i];   // initial centroids = first K points
    int *assign = malloc((size_t)N * sizeof(int));

    for (int iter = 0; iter < ITERS; iter++) {
        for (int i = 0; i < N; i++) {                 // assignment
            int best = 0; long bd = -1;
            for (int k = 0; k < K; k++) {
                long dist = 0;
                for (int d = 0; d < D; d++) { long df = pt[(long)i * D + d] - cen[k * D + d]; dist += df * df; }
                if (bd < 0 || dist < bd) { bd = dist; best = k; }
            }
            assign[i] = best;
        }
        long ssum[K * D] = {0}; long cnt[K] = {0};    // update: floor-mean, empty unchanged
        for (int i = 0; i < N; i++) {
            int k = assign[i]; cnt[k]++;
            for (int d = 0; d < D; d++) ssum[k * D + d] += pt[(long)i * D + d];
        }
        for (int k = 0; k < K; k++)
            if (cnt[k] > 0)
                for (int d = 0; d < D; d++) cen[k * D + d] = ssum[k * D + d] / cnt[k];
    }

    for (int i = 0; i < N; i++) {                      // final assignment with final centroids
        int best = 0; long bd = -1;
        for (int k = 0; k < K; k++) {
            long dist = 0;
            for (int d = 0; d < D; d++) { long df = pt[(long)i * D + d] - cen[k * D + d]; dist += df * df; }
            if (bd < 0 || dist < bd) { bd = dist; best = k; }
        }
        assign[i] = best;
    }

    long h = 0;
    for (int i = 0; i < K * D; i++) h = (h * 31 + cen[i]) % P;
    for (int i = 0; i < N; i++) h = (h * 31 + assign[i]) % P;
    printf("%ld\n", h);
    printf("k-means(%d)\n", N);
    return 0;
}
