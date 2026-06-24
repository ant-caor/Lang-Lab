import sys
import time
import threading

# gemm-par-threads: threading variant of gemm for wall-clock scaling measurement.
# Invocation: python gemm-par-threads.py <cores> <n>
# argv[1]=cores (thread count), argv[2]=n
# SAME decomposition as gemm-par.py (contiguous row bands, pinned i->k->j loop),
# but using threads instead of processes. Under CPython the GIL serialises the
# Python bytecode, so this will show ~1.0x speedup regardless of core count --
# the point is to measure the GIL penalty honestly.
# Result is bit-identical to serial gemm for any number of threads.

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


def compute_band(A, B, n, row_start, row_end, out, band_idx):
    """Worker thread: compute a contiguous band of output rows [row_start, row_end)."""
    band_rows = row_end - row_start
    C_band = [0] * (band_rows * n)
    for i in range(row_start, row_end):
        bi = i - row_start
        for k in range(n):
            a = A[i * n + k]
            kn = k * n
            base = bi * n
            for j in range(n):
                C_band[base + j] += a * B[kn + j]
    out[band_idx] = C_band


def gemm_par_threads(num_threads, n):
    A, B = build_matrices(n)

    # Partition N rows into `num_threads` contiguous bands (same split as gemm-par.py).
    threads = []
    results = [None] * num_threads

    _t0 = time.perf_counter_ns()
    for w in range(num_threads):
        row_start = w * n // num_threads
        row_end = (w + 1) * n // num_threads
        t = threading.Thread(
            target=compute_band,
            args=(A, B, n, row_start, row_end, results, w),
        )
        threads.append(t)

    for t in threads:
        t.start()
    for t in threads:
        t.join()
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
    num_threads = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 256
    h, sec = gemm_par_threads(num_threads, n)
    print(h)
    print("gemm(%d) = %d" % (n, sec))
