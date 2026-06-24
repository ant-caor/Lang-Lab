// gbdt-par: parallel GBDT inference for the wall-clock scaling track.
// Invocation: gbdt-par <cores> <n>
// Output: identical to serial gbdt at the same n (core-invariant).
//
// Decomposition: partition N samples into `cores` contiguous bands.  Each worker
// evaluates all B trees for its samples and writes per-sample accumulator values
// into a disjoint sub-slice of a flat `acc` buffer.  Tree arrays (feat, thr,
// leafval) are read-only and shared across all workers.  After all workers join,
// the main thread computes the checksum in the same serial order as the serial
// benchmark.
//
// Build:
//   rustc -O languages/rust/gbdt-par.rs -o /app/gbdt-par
use std::env;

const P: i64 = 1000000007;
const D: usize = 8;
const B: usize = 200;
const F: i32 = 8;
const NODES: usize = 511;
const LEAF_START: usize = 255;

fn lcg(s: i64) -> i64 {
    (s.wrapping_mul(1103515245).wrapping_add(12345)) & 0x7fffffff
}

fn main() {
    let mut args = env::args().skip(1);
    let cores: usize = args
        .next()
        .and_then(|s| s.parse().ok())
        .unwrap_or(1);
    let n: usize = args
        .next()
        .and_then(|s| s.parse().ok())
        .unwrap_or(5000);

    let cores = cores.max(1).min(n);

    // Build tree arrays (identical LCG sequence as serial gbdt).
    let mut feat    = vec![0i32; B * NODES];
    let mut thr     = vec![0i32; B * NODES];
    let mut leafval = vec![0i32; B * NODES];

    let mut s: i64 = 42;
    for b in 0..B {
        let base = b * NODES;
        for node in 0..LEAF_START {
            s = lcg(s); feat[base + node] = (s % F as i64) as i32;
            s = lcg(s); thr [base + node] = (s % 256) as i32;
        }
        for node in LEAF_START..NODES {
            s = lcg(s); leafval[base + node] = (s % 10) as i32;
        }
    }

    let mut sample = vec![0i32; n * F as usize];
    for v in sample.iter_mut() {
        s = lcg(s);
        *v = (s % 256) as i32;
    }

    // Per-sample accumulator; workers write disjoint bands.
    let mut acc_buf: Vec<i64> = vec![0i64; n];

    // Floor-division sample bands.
    let bands: Vec<(usize, usize)> = (0..cores)
        .map(|w| (w * n / cores, (w + 1) * n / cores))
        .collect();

    // Split acc_buf into per-band mutable slices.
    let mut band_slices: Vec<*mut [i64]> = Vec::with_capacity(cores);
    {
        let mut remaining: &mut [i64] = &mut acc_buf;
        let mut offset = 0usize;
        for w in 0..cores {
            let (_, end) = bands[w];
            let len = end - offset;
            let (head, tail) = remaining.split_at_mut(len);
            band_slices.push(head as *mut [i64]);
            remaining = tail;
            offset = end;
        }
    }

    let feat_ref: &[i32]    = &feat;
    let thr_ref: &[i32]     = &thr;
    let leafval_ref: &[i32] = &leafval;
    let sample_ref: &[i32]  = &sample;

    let t0 = std::time::Instant::now();
    std::thread::scope(|scope| {
        for w in 0..cores {
            let (start, end) = bands[w];
            let ptr = band_slices[w];
            // SAFETY: band_slices[w] is a unique non-overlapping segment of acc_buf
            // derived from split_at_mut.  No other thread writes to it.
            let acc_band: &mut [i64] = unsafe { &mut *ptr };
            scope.spawn(move || {
                for i in start..end {
                    let sbase = i * F as usize;
                    let mut acc: i64 = 0;
                    for b in 0..B {
                        let tbase = b * NODES;
                        let mut node: usize = 0;
                        for _ in 0..D {
                            if sample_ref[sbase + feat_ref[tbase + node] as usize]
                                <= thr_ref[tbase + node]
                            {
                                node = 2 * node + 1;
                            } else {
                                node = 2 * node + 2;
                            }
                        }
                        acc += leafval_ref[tbase + node] as i64;
                    }
                    acc_band[i - start] = acc;
                }
            });
        }
    });
    eprintln!("COMPUTE_NS {}", t0.elapsed().as_nanos());

    // Serial checksum (identical order to serial gbdt).
    let mut h: i64 = 0;
    let mut total: i64 = 0;
    for acc in &acc_buf {
        h     = (h * 31 + acc + 1) % P;
        total = (total + acc) % P;
    }
    println!("{}", h);
    println!("gbdt({}) = {}", n, total);
}
