# Mandelbrot set over an N x N grid of the complex plane [-1.5, 0.5] x [-1.0, 1.0].
# A pixel is "in the set" if |z| stays <= 2 (i.e. zr^2+zi^2 <= 4) through 50 iterations
# of z := z^2 + c starting from z = 0. The checksum is the count of in-set pixels.
#
# CPython float is C double (IEEE-754 binary64) and each op is separately rounded.
# The 2*zr*zi term is written as t+t (t = zr*zi) instead of 2.0*zr*zi so there is NO
# multiply-add pattern to FMA-contract; t+t is bit-identical to 2.0*t. This keeps the
# result bit-exact across every language.
import sys


def mandelbrot(n):
    count = 0
    for y in range(n):
        ci = 2.0 * y / n - 1.0
        for x in range(n):
            cr = 2.0 * x / n - 1.5
            zr = 0.0
            zi = 0.0
            tr = 0.0
            ti = 0.0
            i = 0
            while i < 50 and tr + ti <= 4.0:
                t = zr * zi
                zi = t + t + ci   # == 2*zr*zi + ci, FMA-proof
                zr = tr - ti + cr
                tr = zr * zr
                ti = zi * zi
                i += 1
            if tr + ti <= 4.0:   # never escaped -> in set
                count += 1
    return count


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 128
    print(mandelbrot(n))
    print("mandelbrot(%d)" % n)
