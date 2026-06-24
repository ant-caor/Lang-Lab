# blur-par: parallel multiprocessing variant of blur.
# Invocation: python blur-par.py <cores> <n>
# argv[1]=cores, argv[2]=n
#
# Parallelism is per-pass: for each of PASSES double-buffered passes, divide the NxN
# output rows into `cores` contiguous bands. Each worker reads the input buffer (all
# rows; it needs neighbour rows for the 3x3 stencil including clamped borders) and
# writes its output rows. The parent reassembles the full output buffer from bands in
# row order, then swaps src/dst for the next pass.
#
# Each pass is a synchronisation barrier: the parent joins all workers before swapping
# and starting the next pass. This matches the serial double-buffer swap.
#
# Border clamping: clamp(i+di, n) = max(0, min(n-1, i+di)) -- edge-replication,
# identical to the serial clampi().
#
# Core-invariance: each output pixel value depends only on the input buffer and the
# clamped neighbourhood -- independent of core count. Band boundaries never produce
# different pixel values because workers only READ neighbour rows; they do not write
# outside their band.

import sys
import time
import multiprocessing

P = 1000000007
PASSES = 4
K = (1, 2, 1, 2, 4, 2, 1, 2, 1)  # 3x3 Gaussian kernel, sum=16


def clampi(x, n):
    return 0 if x < 0 else (n - 1 if x >= n else x)


def blur_band(args):
    """Worker: compute output rows [row_start, row_end) of one blur pass."""
    src, n, row_start, row_end = args
    band_len = (row_end - row_start) * n
    dst_band = [0] * band_len
    for i in range(row_start, row_end):
        li = i - row_start  # local row index within this band
        for j in range(n):
            acc = 0
            for di in (-1, 0, 1):
                ni = clampi(i + di, n)
                for dj in (-1, 0, 1):
                    nj = clampi(j + dj, n)
                    acc += K[(di + 1) * 3 + (dj + 1)] * src[ni * n + nj]
            dst_band[li * n + j] = acc // 16
    return dst_band


def blur_par(cores, n):
    src = [0] * (n * n)

    s = 42
    for k in range(n * n):
        s = (s * 1103515245 + 12345) & 0x7FFFFFFF
        src[k] = s % 256

    # Band boundaries (constant across passes and core counts).
    bands_args_template = []
    for w in range(cores):
        row_start = w * n // cores
        row_end = (w + 1) * n // cores
        bands_args_template.append((row_start, row_end))

    _t0 = time.perf_counter_ns()
    for _ in range(PASSES):
        band_args = [(src, n, row_start, row_end)
                     for row_start, row_end in bands_args_template]

        if cores == 1:
            results = [blur_band(band_args[0])]
        else:
            with multiprocessing.Pool(processes=cores) as pool:
                results = pool.map(blur_band, band_args)

        # Assemble full dst from bands in row order (deterministic).
        dst = []
        for band in results:
            dst.extend(band)

        # Double-buffer swap: output of this pass becomes input of next.
        src = dst
    _t1 = time.perf_counter_ns()
    print(f"COMPUTE_NS {_t1 - _t0}", file=sys.stderr)

    h = 0
    for k in range(n * n):
        h = (h * 31 + src[k]) % P
    return h


if __name__ == "__main__":
    cores = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 256
    print(blur_par(cores, n))
    print("blur(%d)" % n)
