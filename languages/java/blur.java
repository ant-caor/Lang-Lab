// blur: a 2D image-convolution benchmark - the stencil axis of the suite. Generate a
// grayscale N x N image, then apply a 3x3 Gaussian blur kernel [1 2 1; 2 4 2; 1 2 1]/16
// PASSES times (double-buffered), with clamp (edge-replication) border handling, and reduce
// the result to a polynomial hash. All integer arithmetic - deterministic, no floating point.

class Blur {
    static final long P = 1000000007L;
    static final int PASSES = 4;

    static long lcg(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }
    static int clampi(int x, int n) { return x < 0 ? 0 : (x >= n ? n - 1 : x); }

    static long blur(int n) {
        int[] k = {1, 2, 1, 2, 4, 2, 1, 2, 1};   // 3x3, sum 16
        int[] src = new int[n * n];
        int[] dst = new int[n * n];
        long s = 42L;
        for (int idx = 0; idx < n * n; idx++) {
            s = lcg(s);
            src[idx] = (int) (s % 256);
        }
        for (int pass = 0; pass < PASSES; pass++) {
            for (int i = 0; i < n; i++) {
                for (int j = 0; j < n; j++) {
                    int acc = 0;
                    for (int di = -1; di <= 1; di++) {
                        int ni = clampi(i + di, n);
                        for (int dj = -1; dj <= 1; dj++) {
                            int nj = clampi(j + dj, n);
                            acc += k[(di + 1) * 3 + (dj + 1)] * src[ni * n + nj];
                        }
                    }
                    dst[i * n + j] = acc / 16;   // integer division
                }
            }
            int[] t = src; src = dst; dst = t;   // double-buffer swap
        }
        long h = 0L;
        for (int idx = 0; idx < n * n; idx++) {
            h = (h * 31 + src[idx]) % P;
        }
        return h;
    }

    public static void main(String[] args) {
        int n = args.length > 0 ? Integer.parseInt(args[0]) : 256;
        System.out.println(blur(n));
        System.out.println("blur(" + n + ")");
    }
}
