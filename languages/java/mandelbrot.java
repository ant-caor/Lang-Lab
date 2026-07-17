// Mandelbrot set over an N x N grid of the complex plane [-1.5, 0.5] x [-1.0, 1.0].
// A pixel is "in the set" if |z| stays <= 2 (i.e. zr^2+zi^2 <= 4) through 50 iterations
// of z := z^2 + c starting from z = 0. The checksum is the count of in-set pixels.
//
// IEEE-754 double throughout. The 2*zr*zi term is written as t+t (t = zr*zi) instead
// of 2.0*zr*zi so there is NO multiply-add pattern for a compiler to FMA-contract; t+t
// is bit-identical to 2.0*t. This keeps the result bit-exact across every language
// regardless of FMA, fast-math defaults, or auto-vectorization.

class Mandelbrot {
    static long mandelbrot(int n) {
        long count = 0L;
        for (int y = 0; y < n; y++) {
            double ci = 2.0 * y / n - 1.0;
            for (int x = 0; x < n; x++) {
                double cr = 2.0 * x / n - 1.5;
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
                if (tr + ti <= 4.0) count++;   // never escaped -> in set
            }
        }
        return count;
    }

    public static void main(String[] args) {
        int n = args.length > 0 ? Integer.parseInt(args[0]) : 128;
        System.out.println(mandelbrot(n));
        System.out.println("mandelbrot(" + n + ")");
    }
}
