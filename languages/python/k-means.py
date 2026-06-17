import sys

P = 1000000007
K = 16
D = 4
ITERS = 10
RANGE = 256


def k_means(n):
    # 1. Generate N integer D-dimensional points with the pinned LCG
    pt = [0] * (n * D)
    state = 42
    for i in range(n * D):
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        pt[i] = state % RANGE
    cen = pt[: K * D]                       # initial centroids = first K points
    assign = [0] * n

    # 2. ITERS iterations of assign + update
    for _ in range(ITERS):
        for i in range(n):                  # assignment - nearest centroid
            base = i * D
            best = 0
            bd = -1
            for k in range(K):
                kb = k * D
                dist = 0
                for d in range(D):
                    df = pt[base + d] - cen[kb + d]
                    dist += df * df
                if bd < 0 or dist < bd:     # STRICT < : ties go to the lowest k
                    bd = dist
                    best = k
            assign[i] = best
        ssum = [0] * (K * D)                # update - floor-mean, empty unchanged
        cnt = [0] * K
        for i in range(n):
            k = assign[i]
            cnt[k] += 1
            base = i * D
            kb = k * D
            for d in range(D):
                ssum[kb + d] += pt[base + d]
        for k in range(K):
            if cnt[k] > 0:
                kb = k * D
                c = cnt[k]
                for d in range(D):
                    cen[kb + d] = ssum[kb + d] // c   # INTEGER (floor) division

    for i in range(n):                      # final assignment with final centroids
        base = i * D
        best = 0
        bd = -1
        for k in range(K):
            kb = k * D
            dist = 0
            for d in range(D):
                df = pt[base + d] - cen[kb + d]
                dist += df * df
            if bd < 0 or dist < bd:
                bd = dist
                best = k
        assign[i] = best

    h = 0
    for v in cen:
        h = (h * 31 + v) % P
    for i in range(n):
        h = (h * 31 + assign[i]) % P
    return h


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    print(k_means(n))
    print("k-means(%d)" % n)
