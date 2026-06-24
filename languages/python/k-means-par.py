# k-means-par: parallel multiprocessing variant of k-means.
# Invocation: python k-means-par.py <cores> <n>
# argv[1]=cores, argv[2]=n
#
# Parallel decomposition: per iteration, the ASSIGNMENT step is embarrassingly parallel
# over the N points. Each worker receives a contiguous band of points and returns:
#   - assign_band: list of cluster indices for its points
#   - ssum_band:   partial coordinate sums per cluster (K*D flat list)
#   - cnt_band:    partial point counts per cluster (K list)
#
# The parent SERIALLY merges partial sums/counts and updates centroids (floor-mean,
# empty-cluster unchanged) -- identical to the serial benchmark.
#
# The FINAL assignment (after ITERS iterations) is also parallelised the same way.
#
# Core-invariance:
#   - Points are assigned in the same order within each band (workers preserve point order).
#   - Strict-< tie-break is preserved per-point (lowest-k wins) -- no cross-point ordering.
#   - Centroid update is fully serial, so centroids are bit-identical to serial at every iter.
#   - The final assign[] array is assembled from bands in deterministic (band = point) order.
#   - The checksum iterates cen[] then assign[] in the same order as serial.

import sys
import time
import multiprocessing

P = 1000000007
K_CLUSTERS = 16
D = 4
ITERS = 10
RANGE = 256


def assign_band(args):
    """Worker: assign points [pt_start, pt_end) to nearest centroid.

    Returns (assign_band, ssum_band, cnt_band).
    """
    pt, cen, pt_start, pt_end = args
    band_n = pt_end - pt_start
    assign_b = [0] * band_n
    ssum_b = [0] * (K_CLUSTERS * D)
    cnt_b = [0] * K_CLUSTERS

    for ii in range(band_n):
        i = pt_start + ii
        base = i * D
        best = 0
        bd = -1
        for k in range(K_CLUSTERS):
            kb = k * D
            dist = 0
            for d in range(D):
                df = pt[base + d] - cen[kb + d]
                dist += df * df
            if bd < 0 or dist < bd:     # STRICT < : ties go to the lowest k
                bd = dist
                best = k
        assign_b[ii] = best
        cnt_b[best] += 1
        kb = best * D
        for d in range(D):
            ssum_b[kb + d] += pt[base + d]

    return assign_b, ssum_b, cnt_b


def k_means_par(cores, n):
    # 1. Generate N integer D-dimensional points with the pinned LCG.
    pt = [0] * (n * D)
    state = 42
    for i in range(n * D):
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        pt[i] = state % RANGE

    cen = list(pt[: K_CLUSTERS * D])   # initial centroids = first K points

    # Band boundaries (floor-division rule, constant across iters and core counts).
    bands = []
    for w in range(cores):
        pt_start = w * n // cores
        pt_end = (w + 1) * n // cores
        bands.append((pt_start, pt_end))

    # 2. ITERS iterations of parallel assign + serial centroid update.
    _t0 = time.perf_counter_ns()
    for _ in range(ITERS):
        band_args = [(pt, cen, pt_start, pt_end) for pt_start, pt_end in bands]

        if cores == 1:
            results = [assign_band(band_args[0])]
        else:
            with multiprocessing.Pool(processes=cores) as pool:
                results = pool.map(assign_band, band_args)

        # Serial centroid update: merge partial sums/counts from all bands.
        ssum = [0] * (K_CLUSTERS * D)
        cnt = [0] * K_CLUSTERS
        for _, ssum_b, cnt_b in results:
            for idx in range(K_CLUSTERS * D):
                ssum[idx] += ssum_b[idx]
            for k in range(K_CLUSTERS):
                cnt[k] += cnt_b[k]

        for k in range(K_CLUSTERS):
            if cnt[k] > 0:
                kb = k * D
                c = cnt[k]
                for d in range(D):
                    cen[kb + d] = ssum[kb + d] // c   # INTEGER (floor) division

    # 3. Final assignment with final centroids (parallelised the same way).
    band_args = [(pt, cen, pt_start, pt_end) for pt_start, pt_end in bands]

    if cores == 1:
        final_results = [assign_band(band_args[0])]
    else:
        with multiprocessing.Pool(processes=cores) as pool:
            final_results = pool.map(assign_band, band_args)
    _t1 = time.perf_counter_ns()
    print(f"COMPUTE_NS {_t1 - _t0}", file=sys.stderr)

    # Assemble full assign[] in band (point) order.
    assign = []
    for assign_b, _, _ in final_results:
        assign.extend(assign_b)

    # Checksum: identical to serial (cen[] then assign[]).
    h = 0
    for v in cen:
        h = (h * 31 + v) % P
    for i in range(n):
        h = (h * 31 + assign[i]) % P
    return h


if __name__ == "__main__":
    cores = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 8000
    print(k_means_par(cores, n))
    print("k-means(%d)" % n)
