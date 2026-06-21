import sys

# viterbi: integer HMM sequence decoding — the classical max-plus trellis.
# S=8 states, ALPHA=4 symbols, T=size parameter. LCG (glibc-style, seed=42)
# draws trans[S*S], emit[S*ALPHA], obs[T] in that order. Forward pass is a
# loop-carried max-reduction (STRICT > tie-break: lowest i wins), followed by a
# pointer-chain backtrace. Checksum = poly-hash of (path[t]+1).
# Secondary = optimal total path score mod P. No HMM library; pure integer.

S = 8
ALPHA = 4
P = 1000000007


def lcg(s):
    return (s * 1103515245 + 12345) & 0x7FFFFFFF


def viterbi(t):
    # Draw order: trans[S*S], emit[S*ALPHA], obs[T]
    state = 42
    trans = [0] * (S * S)
    for x in range(S * S):
        state = lcg(state)
        trans[x] = state % 100 + 1

    emit = [0] * (S * ALPHA)
    for x in range(S * ALPHA):
        state = lcg(state)
        emit[x] = state % 100 + 1

    obs = [0] * t
    for i in range(t):
        state = lcg(state)
        obs[i] = state % ALPHA

    # Initialise t=0
    vit_prev = [emit[j * ALPHA + obs[0]] for j in range(S)]
    vit_next = [0] * S

    # back[t*S+j]
    back = [0] * (t * S)

    # Forward trellis t=1..T-1
    for ti in range(1, t):
        for j in range(S):
            best = -1
            bi = 0
            emit_base = j * ALPHA + obs[ti]
            e = emit[emit_base]
            for i in range(S):
                sc = vit_prev[i] + trans[i * S + j] + e
                if sc > best:   # STRICT > -> lowest i wins ties
                    best = sc
                    bi = i
            vit_next[j] = best
            back[ti * S + j] = bi
        vit_prev, vit_next = vit_next, vit_prev

    # Final state: STRICT > -> lowest j wins
    bf = 0
    for j in range(1, S):
        if vit_prev[j] > vit_prev[bf]:
            bf = j

    # Backtrace
    path = [0] * t
    path[t - 1] = bf
    for ti in range(t - 2, -1, -1):
        path[ti] = back[(ti + 1) * S + path[ti + 1]]

    # Checksum
    h = 0
    for ti in range(t):
        h = (h * 31 + path[ti] + 1) % P

    secondary = vit_prev[bf] % P
    return h, secondary


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
    h, sec = viterbi(n)
    print(h)
    print("viterbi(%d) = %d" % (n, sec))
