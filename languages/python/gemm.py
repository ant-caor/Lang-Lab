import sys

# gemm: quantized integer matrix-multiply - the dominant ML inference kernel.
# Square matmul of side N (i.e. N x N matrices). Loop order i,k,j (pinned)
# so B is accessed row-sequentially. LCG fills A then B with values 0..127.
# Accumulator is 64-bit; checksum = poly-hash of C row-major mod 1e9+7.
# No BLAS / no numpy.dot / no @ operator - the explicit triple loop.

P = 1000000007


def gemm(n):
    A = [0] * (n * n)
    B = [0] * (n * n)

    state = 42
    for i in range(n * n):
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        A[i] = state % 128
    for i in range(n * n):
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        B[i] = state % 128

    C = [0] * (n * n)
    # Pinned loop order i, k, j - B read row-sequentially.
    for i in range(n):
        for k in range(n):
            a = A[i * n + k]
            kn = k * n
            base = i * n
            for j in range(n):
                C[base + j] += a * B[kn + j]

    h = 0
    for v in C:
        h = (h * 31 + v % P) % P
    secondary = C[n * n - 1] % P
    return h, secondary


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 256
    h, sec = gemm(n)
    print(h)
    print("gemm(%d) = %d" % (n, sec))
