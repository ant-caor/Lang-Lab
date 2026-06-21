// gemm: quantized integer matrix-multiply - the dominant ML inference kernel.
// Square matmul of side N (i.e. N x N matrices). Loop order i,k,j (pinned)
// so B is accessed row-sequentially. LCG fills A then B with values 0..127.
// Accumulator is 64-bit; checksum = poly-hash of C row-major mod 1e9+7.
// No BLAS / no library matmul - the explicit triple loop in every language.
#include <stdio.h>
#include <stdlib.h>

#define P 1000000007L

static long lcg(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }

int main(int argc, char **argv) {
    int N = argc > 1 ? atoi(argv[1]) : 256;
    long *A = malloc((size_t)N * N * sizeof(long));
    long *B = malloc((size_t)N * N * sizeof(long));
    long *C = calloc((size_t)N * N, sizeof(long));

    long s = 42;
    for (int i = 0; i < N * N; i++) { s = lcg(s); A[i] = s % 128; }
    for (int i = 0; i < N * N; i++) { s = lcg(s); B[i] = s % 128; }

    // Pinned loop order i, k, j - B read row-sequentially.
    for (int i = 0; i < N; i++) {
        for (int k = 0; k < N; k++) {
            long a = A[i * N + k];
            for (int j = 0; j < N; j++) {
                C[i * N + j] += a * B[k * N + j];
            }
        }
    }

    long h = 0;
    for (int i = 0; i < N * N; i++) h = (h * 31 + C[i] % P) % P;
    long secondary = C[N * N - 1] % P;
    printf("%ld\n", h);
    printf("gemm(%d) = %ld\n", N, secondary);

    free(A); free(B); free(C);
    return 0;
}
