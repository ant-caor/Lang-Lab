// gemm: quantized integer matrix-multiply - the dominant ML inference kernel.
// Square matmul of side N (i.e. N x N matrices). Loop order i,k,j (pinned)
// so B is accessed row-sequentially. LCG fills A then B with values 0..127.
// Accumulator is 64-bit; checksum = poly-hash of C row-major mod 1e9+7.
// No BLAS / no library matmul - the explicit triple loop.

class Gemm {
    static final long P = 1000000007L;

    static long lcg(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }

    static long[] gemm(int n) {
        long[] A = new long[n * n];
        long[] B = new long[n * n];
        long[] C = new long[n * n];

        long s = 42L;
        for (int i = 0; i < n * n; i++) { s = lcg(s); A[i] = s % 128; }
        for (int i = 0; i < n * n; i++) { s = lcg(s); B[i] = s % 128; }

        // Pinned loop order i, k, j - B read row-sequentially.
        for (int i = 0; i < n; i++) {
            for (int k = 0; k < n; k++) {
                long a = A[i * n + k];
                int kn = k * n;
                int base = i * n;
                for (int j = 0; j < n; j++) {
                    C[base + j] += a * B[kn + j];
                }
            }
        }

        long h = 0L;
        for (int i = 0; i < n * n; i++) h = (h * 31 + C[i] % P) % P;
        long secondary = C[n * n - 1] % P;
        return new long[]{h, secondary};
    }

    public static void main(String[] args) {
        int n = args.length > 0 ? Integer.parseInt(args[0]) : 256;
        long[] res = gemm(n);
        System.out.println(res[0]);
        System.out.println("gemm(" + n + ") = " + res[1]);
    }
}
