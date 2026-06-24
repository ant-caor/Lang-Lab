# gbdt-par: parallel multiprocessing variant of gbdt.
# Invocation: python gbdt-par.py <cores> <n>
# argv[1]=cores, argv[2]=n
#
# Parallel decomposition: divide the N samples into `cores` contiguous bands.
# Each worker traverses all B trees for its samples (trees are read-only, static).
# The worker returns a list of (h_band, total_band) where h_band is the partial
# poly-hash for its samples and total_band is the partial sum of acc values.
#
# IMPORTANT: the poly-hash h is order-dependent (h = h*31 + acc+1), so the parent
# must continue hashing from the last h produced by the previous band. Workers
# cannot hash independently and have the parent combine hashes -- the reduction is
# not associative for a poly-hash.
#
# Instead, each worker returns its raw acc values in order, and the parent computes
# the checksum serially over the concatenated acc array (in band=sample order).
# This guarantees core-invariance and matches the serial benchmark exactly.
#
# Core-invariance:
#   - Tree arrays are read-only (feat, thr, leafval built identically).
#   - Each worker computes acc[i] deterministically (same tree traversal as serial).
#   - acc values are assembled in sample order before checksumming.
#   - The final checksum pass is serial and identical to serial gbdt.

import sys
import time
import multiprocessing

P = 1000000007
D = 8
B = 200
F = 8
NODES = (1 << (D + 1)) - 1    # 511
LEAF_START = (1 << D) - 1     # 255


def lcg(s):
    return (s * 1103515245 + 12345) & 0x7FFFFFFF


def build_trees(state):
    """Generate feat, thr, leafval arrays -- identical to serial gbdt.py."""
    feat = [0] * (B * NODES)
    thr = [0] * (B * NODES)
    leafval = [0] * (B * NODES)
    for b in range(B):
        base = b * NODES
        for node in range(LEAF_START):         # internal nodes: feat then thr
            state = lcg(state)
            feat[base + node] = state % F
            state = lcg(state)
            thr[base + node] = state % 256
        for node in range(LEAF_START, NODES):  # leaves
            state = lcg(state)
            leafval[base + node] = state % 10
    return feat, thr, leafval, state


def infer_band(args):
    """Worker: infer all B trees for samples [samp_start, samp_end).

    Returns a list of acc values (one per sample, in order).
    """
    feat, thr, leafval, sample, F_local, samp_start, samp_end = args
    acc_list = []
    for i in range(samp_start, samp_end):
        sbase = i * F_local
        acc = 0
        for b in range(B):
            tbase = b * NODES
            node = 0
            for _ in range(D):
                if sample[sbase + feat[tbase + node]] <= thr[tbase + node]:
                    node = 2 * node + 1
                else:
                    node = 2 * node + 2
            acc += leafval[tbase + node]
        acc_list.append(acc)
    return acc_list


def gbdt_par(cores, n):
    # Build tree arrays (single-threaded, identical to serial).
    feat, thr, leafval, state = build_trees(42)

    # Generate sample data (continues from the tree-building LCG state).
    sample = [0] * (n * F)
    for i in range(n * F):
        state = lcg(state)
        sample[i] = state % 256

    # Band boundaries (floor-division rule).
    bands = []
    for w in range(cores):
        samp_start = w * n // cores
        samp_end = (w + 1) * n // cores
        bands.append((feat, thr, leafval, sample, F, samp_start, samp_end))

    _t0 = time.perf_counter_ns()
    if cores == 1:
        results = [infer_band(bands[0])]
    else:
        with multiprocessing.Pool(processes=cores) as pool:
            results = pool.map(infer_band, bands)
    _t1 = time.perf_counter_ns()
    print(f"COMPUTE_NS {_t1 - _t0}", file=sys.stderr)

    # Assemble acc values in sample order (deterministic).
    # Compute checksum serially -- identical to serial gbdt.
    h = 0
    total = 0
    for band_acc in results:
        for acc in band_acc:
            h = (h * 31 + acc + 1) % P
            total = (total + acc) % P

    return h, total


if __name__ == "__main__":
    cores = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 5000
    h, sec = gbdt_par(cores, n)
    print(h)
    print("gbdt(%d) = %d" % (n, sec))
