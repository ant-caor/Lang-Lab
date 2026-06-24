import sys
import time
import multiprocessing

# gemm-par: parallel multiprocessing variant of gemm.
# Invocation: python gemm-par.py <cores> <n>
# argv[1]=cores, argv[2]=n
# Decomposes the N output rows of C into `cores` contiguous bands.
# Each worker computes its band with the SAME pinned i->k->j loop order as serial.
# The parent assembles bands in order then checksums identically to serial.
# Result is bit-identical to serial gemm for any number of cores.

P = 1000000007


def build_matrices(n):
    """Generate A and B via the pinned LCG (identical to serial gemm.py)."""
    A = [0] * (n * n)
    B = [0] * (n * n)
    state = 42
    for i in range(n * n):
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        A[i] = state % 128
    for i in range(n * n):
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        B[i] = state % 128
    return A, B


def compute_band(args):
    """Worker: compute a contiguous band of output rows [row_start, row_end)."""
    A, B, n, row_start, row_end = args
    # Only allocate the slice of C this worker needs.
    band_rows = row_end - row_start
    C_band = [0] * (band_rows * n)
    for i in range(row_start, row_end):
        bi = i - row_start  # local row index within this band
        for k in range(n):
            a = A[i * n + k]
            kn = k * n
            base = bi * n
            for j in range(n):
                C_band[base + j] += a * B[kn + j]
    return C_band


def gemm_par(cores, n):
    A, B = build_matrices(n)

    # Partition N rows into `cores` contiguous bands (core-invariant split).
    bands = []
    for w in range(cores):
        row_start = w * n // cores
        row_end = (w + 1) * n // cores
        bands.append((A, B, n, row_start, row_end))

    _t0 = time.perf_counter_ns()
    if cores == 1:
        # Skip process-pool overhead for single-core case.
        results = [compute_band(bands[0])]
    else:
        with multiprocessing.Pool(processes=cores) as pool:
            results = pool.map(compute_band, bands)
    _t1 = time.perf_counter_ns()
    print(f"COMPUTE_NS {_t1 - _t0}", file=sys.stderr)

    # Assemble full C in band order (deterministic, identical to serial row order).
    C = []
    for band in results:
        C.extend(band)

    # Checksum: poly-hash row-major, identical to serial gemm.py.
    h = 0
    for v in C:
        h = (h * 31 + v % P) % P
    secondary = C[n * n - 1] % P
    return h, secondary


if __name__ == "__main__":
    cores = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 256
    h, sec = gemm_par(cores, n)
    print(h)
    print("gemm(%d) = %d" % (n, sec))
