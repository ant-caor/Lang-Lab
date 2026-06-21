// viterbi: integer HMM sequence decoding — the classical max-plus trellis.
// S=8 states, ALPHA=4 symbols, T=size parameter. LCG (glibc-style, seed=42)
// draws trans[S*S], emit[S*ALPHA], obs[T] in that order. The forward pass is a
// loop-carried max-reduction (STRICT > tie-break: lowest i wins), followed by a
// pointer-chain backtrace. Checksum = poly-hash of (path[t]+1). Secondary = the
// optimal total path score mod P. No HMM library; pure integer, no log/exp.
#include <stdio.h>
#include <stdlib.h>

#define S      8
#define ALPHA  4
#define P      1000000007L

static long lcg(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }

int main(int argc, char **argv) {
    int T = argc > 1 ? atoi(argv[1]) : 20000;

    // Draw order: trans[S*S], emit[S*ALPHA], obs[T]
    long trans[S * S], emit_t[S * ALPHA];
    int *obs  = malloc((size_t)T * sizeof(int));
    int *back = malloc((size_t)T * S * sizeof(int));
    int *path = malloc((size_t)T * sizeof(int));

    long s = 42;
    for (int x = 0; x < S * S; x++) { s = lcg(s); trans[x] = s % 100 + 1; }
    for (int x = 0; x < S * ALPHA; x++) { s = lcg(s); emit_t[x] = s % 100 + 1; }
    for (int t = 0; t < T; t++) { s = lcg(s); obs[t] = (int)(s % ALPHA); }

    // Initialise t=0
    long vit_a[S], vit_b[S];
    long *vit_prev = vit_a, *vit_next = vit_b;
    for (int j = 0; j < S; j++) vit_prev[j] = emit_t[j * ALPHA + obs[0]];

    // Forward trellis t=1..T-1
    for (int t = 1; t < T; t++) {
        for (int j = 0; j < S; j++) {
            long best = -1; int bi = 0;
            for (int i = 0; i < S; i++) {
                long sc = vit_prev[i] + trans[i * S + j] + emit_t[j * ALPHA + obs[t]];
                if (sc > best) { best = sc; bi = i; }  // STRICT > -> lowest i wins
            }
            vit_next[j] = best;
            back[t * S + j] = bi;
        }
        long *tmp = vit_prev; vit_prev = vit_next; vit_next = tmp;
    }

    // Final state: STRICT > -> lowest j wins
    int bf = 0;
    for (int j = 1; j < S; j++)
        if (vit_prev[j] > vit_prev[bf]) bf = j;

    // Backtrace
    path[T - 1] = bf;
    for (int t = T - 2; t >= 0; t--) path[t] = back[(t + 1) * S + path[t + 1]];

    // Checksum
    long h = 0;
    for (int t = 0; t < T; t++) h = (h * 31 + path[t] + 1) % P;

    long secondary = vit_prev[bf] % P;
    printf("%ld\n", h);
    printf("viterbi(%d) = %ld\n", T, secondary);

    free(obs); free(back); free(path);
    return 0;
}
