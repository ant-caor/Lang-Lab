// viterbi: integer HMM sequence decoding — the classical max-plus trellis.
// S=8 states, ALPHA=4 symbols, T=size parameter. LCG (glibc-style, seed=42)
// draws trans[S*S], emit[S*ALPHA], obs[T] in that order. Forward pass is a
// loop-carried max-reduction (STRICT > tie-break: lowest i wins), followed by
// a pointer-chain backtrace. Checksum = poly-hash of (path[t]+1).
// Secondary = optimal total path score mod P. No HMM library; pure integer.
use std::env;

const S: usize = 8;
const ALPHA: usize = 4;
const P: i64 = 1000000007;

fn lcg(s: i64) -> i64 {
    (s.wrapping_mul(1103515245).wrapping_add(12345)) & 0x7fffffff
}

fn run(t: usize) -> (i64, i64) {
    // Draw order: trans[S*S], emit[S*ALPHA], obs[T]
    let mut trans = vec![0i64; S * S];
    let mut emit = vec![0i64; S * ALPHA];
    let mut s: i64 = 42;
    for x in 0..S * S {
        s = lcg(s);
        trans[x] = s % 100 + 1;
    }
    for x in 0..S * ALPHA {
        s = lcg(s);
        emit[x] = s % 100 + 1;
    }
    let mut obs = vec![0usize; t];
    for i in 0..t {
        s = lcg(s);
        obs[i] = (s % ALPHA as i64) as usize;
    }

    // Initialise t=0
    let mut vit_prev = vec![0i64; S];
    let mut vit_next = vec![0i64; S];
    for j in 0..S {
        vit_prev[j] = emit[j * ALPHA + obs[0]];
    }

    let mut back = vec![0i32; t * S];

    // Forward trellis t=1..T-1
    for ti in 1..t {
        for j in 0..S {
            let mut best: i64 = -1;
            let mut bi: i32 = 0;
            let e = emit[j * ALPHA + obs[ti]];
            for i in 0..S {
                let sc = vit_prev[i] + trans[i * S + j] + e;
                if sc > best {
                    // STRICT > -> lowest i wins ties
                    best = sc;
                    bi = i as i32;
                }
            }
            vit_next[j] = best;
            back[ti * S + j] = bi;
        }
        std::mem::swap(&mut vit_prev, &mut vit_next);
    }

    // Final state: STRICT > -> lowest j wins
    let mut bf = 0usize;
    for j in 1..S {
        if vit_prev[j] > vit_prev[bf] {
            bf = j;
        }
    }

    // Backtrace
    let mut path = vec![0i32; t];
    path[t - 1] = bf as i32;
    for ti in (0..t - 1).rev() {
        path[ti] = back[(ti + 1) * S + path[ti + 1] as usize];
    }

    // Checksum
    let mut h: i64 = 0;
    for ti in 0..t {
        h = (h * 31 + path[ti] as i64 + 1) % P;
    }
    let secondary = vit_prev[bf] % P;
    (h, secondary)
}

fn main() {
    let t: usize = env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(20000);
    let (h, sec) = run(t);
    println!("{}", h);
    println!("viterbi({}) = {}", t, sec);
}
