# mandelbrot-par: parallel multiprocessing variant of mandelbrot.
# Invocation: python mandelbrot-par.py <cores> <n>
# argv[1]=cores, argv[2]=n
#
# Decomposes the N output rows into `cores` contiguous horizontal bands.
# Each worker counts in-set pixels for its band (pixels are independent).
# The parent sums band counts deterministically (band order = row order).
# Result is bit-identical to serial mandelbrot for any number of cores.
#
# FMA-contraction-proof formula preserved: t=zr*zi; zi=t+t+ci (no 2*zr*zi).

import sys
import time
import multiprocessing


def count_band(args):
    """Worker: count in-set pixels for rows [row_start, row_end)."""
    n, row_start, row_end = args
    count = 0
    for y in range(row_start, row_end):
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
            if tr + ti <= 4.0:
                count += 1
    return count


def mandelbrot_par(cores, n):
    # Partition N rows into `cores` contiguous bands (floor-division rule).
    bands = []
    for w in range(cores):
        row_start = w * n // cores
        row_end = (w + 1) * n // cores
        bands.append((n, row_start, row_end))

    _t0 = time.perf_counter_ns()
    if cores == 1:
        results = [count_band(bands[0])]
    else:
        with multiprocessing.Pool(processes=cores) as pool:
            results = pool.map(count_band, bands)
    _t1 = time.perf_counter_ns()
    print(f"COMPUTE_NS {_t1 - _t0}", file=sys.stderr)

    # Sum band counts in band order (= row order) -- deterministic.
    total = sum(results)
    return total


if __name__ == "__main__":
    cores = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 256
    print(mandelbrot_par(cores, n))
    print("mandelbrot(%d)" % n)
