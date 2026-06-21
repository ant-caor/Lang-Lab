import sys

# gbdt: gradient-boosted decision-tree ensemble inference — the dominant tabular-ML
# algorithm (XGBoost/LightGBM/CatBoost style). B=200 trees of depth D=8 over F=8
# features. Each tree is a flat complete binary tree (NODES=511): internal nodes
# 0..254 store a (feature-index, threshold) split; leaves 255..510 store a value.
# Children of node k: left=2k+1, right=2k+2. Inference: for each sample, traverse
# all B trees (exactly D compare-and-branch steps each) and sum the leaf values.
# Checksum: poly-hash of (acc+1) per sample; secondary = sum of acc values mod P.
# LCG draw order pinned: feat then thr per internal node, leafval per leaf, samples.
# All integer — no float, no ML/tree library.

P          = 1000000007
D          = 8
B          = 200
F          = 8
NODES      = (1 << (D + 1)) - 1    # 511
LEAF_START = (1 << D) - 1          # 255


def lcg(s):
    return (s * 1103515245 + 12345) & 0x7FFFFFFF


def gbdt(n):
    feat    = [0] * (B * NODES)
    thr     = [0] * (B * NODES)
    leafval = [0] * (B * NODES)

    state = 42
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

    sample = [0] * (n * F)
    for i in range(n * F):
        state = lcg(state)
        sample[i] = state % 256

    h = 0
    total = 0
    for i in range(n):
        sbase = i * F
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
        h     = (h * 31 + acc + 1) % P
        total = (total + acc)       % P

    return h, total


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 5000
    h, sec = gbdt(n)
    print(h)
    print("gbdt(%d) = %d" % (n, sec))
