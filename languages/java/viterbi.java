// viterbi: integer HMM sequence decoding - the classical max-plus trellis.
// S=8 states, ALPHA=4 symbols, T=size parameter. LCG (glibc-style, seed=42)
// draws trans[S*S], emit[S*ALPHA], obs[T] in that order. Forward pass is a
// loop-carried max-reduction (STRICT > tie-break: lowest i wins), followed by
// a pointer-chain backtrace. Checksum = poly-hash of (path[t]+1).
// Secondary = optimal total path score mod P. No HMM library; pure integer.

class Viterbi {
    static final int S_VIT = 8;
    static final int ALPHA_VIT = 4;
    static final long P_VIT = 1000000007L;

    static long[] viterbi(int t) {
        // Draw order: trans[S*S], emit[S*ALPHA], obs[T]
        long[] trans = new long[S_VIT * S_VIT];
        long[] emit = new long[S_VIT * ALPHA_VIT];
        int[] obs = new int[t];
        long s = 42L;
        for (int x = 0; x < S_VIT * S_VIT; x++) {
            s = (s * 1103515245L + 12345L) & 0x7fffffffL;
            trans[x] = s % 100L + 1L;
        }
        for (int x = 0; x < S_VIT * ALPHA_VIT; x++) {
            s = (s * 1103515245L + 12345L) & 0x7fffffffL;
            emit[x] = s % 100L + 1L;
        }
        for (int i = 0; i < t; i++) {
            s = (s * 1103515245L + 12345L) & 0x7fffffffL;
            obs[i] = (int) (s % ALPHA_VIT);
        }

        // Initialise t=0
        long[] vitPrev = new long[S_VIT];
        for (int i = 0; i < S_VIT; i++) vitPrev[i] = emit[i * ALPHA_VIT + obs[0]];
        long[] vitNext = new long[S_VIT];

        int[] back = new int[t * S_VIT];

        // Forward trellis t=1..T-1
        for (int ti = 1; ti < t; ti++) {
            for (int j = 0; j < S_VIT; j++) {
                long best = -1L;
                int bi = 0;
                long e = emit[j * ALPHA_VIT + obs[ti]];
                for (int i = 0; i < S_VIT; i++) {
                    long sc = vitPrev[i] + trans[i * S_VIT + j] + e;
                    if (sc > best) { best = sc; bi = i; }   // STRICT > -> lowest i wins
                }
                vitNext[j] = best;
                back[ti * S_VIT + j] = bi;
            }
            long[] tmp = vitPrev; vitPrev = vitNext; vitNext = tmp;
        }

        // Final state: STRICT > -> lowest j wins
        int bf = 0;
        for (int j = 1; j < S_VIT; j++) { if (vitPrev[j] > vitPrev[bf]) bf = j; }

        // Backtrace
        int[] path = new int[t];
        path[t - 1] = bf;
        for (int ti = t - 2; ti >= 0; ti--) path[ti] = back[(ti + 1) * S_VIT + path[ti + 1]];

        // Checksum
        long h = 0L;
        for (int ti = 0; ti < t; ti++) h = (h * 31L + path[ti] + 1L) % P_VIT;

        long secondary = vitPrev[bf] % P_VIT;
        return new long[]{h, secondary};
    }

    public static void main(String[] args) {
        int t = args.length > 0 ? Integer.parseInt(args[0]) : 20000;
        long[] res = viterbi(t);
        System.out.println(res[0]);
        System.out.println("viterbi(" + t + ") = " + res[1]);
    }
}
