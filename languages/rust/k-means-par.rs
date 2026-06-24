// k-means-par: parallel Lloyd's k-means for the wall-clock scaling track.
// Invocation: k-means-par <cores> <n>
// Output: identical to serial k-means at the same n (core-invariant).
//
// Decomposition:
//   ASSIGNMENT step: partition points into `cores` bands.  Each worker computes
//     assignments for its points (same strict-< lowest-index tie-break as serial)
//     and accumulates partial per-cluster coordinate sums and counts.
//   UPDATE step: main thread merges partial sums/counts from all workers and
//     applies floor-mean centroid update (empty-cluster unchanged), same as serial.
//
// Workers write disjoint sub-slices of `assign`.  The partial sums/counts are
// per-worker private arrays passed back via ordinary move captures + a channel-
// free collect after scope.  No atomics on the compute path.
//
// Build:
//   rustc -O languages/rust/k-means-par.rs -o /app/k-means-par
use std::env;

const P: i64 = 1000000007;
const K: usize = 16;
const D: usize = 4;
const ITERS: usize = 10;
const RANGE: i64 = 256;

fn lcg(s: i64) -> i64 {
    (s.wrapping_mul(1103515245).wrapping_add(12345)) & 0x7fffffff
}

/// Assign points [start..end) to nearest centroid (strict-< tie-break).
/// Writes into assign[start..end].
/// Returns (partial_ssum[K*D], partial_cnt[K]) for the assigned points.
fn assign_band(
    pt: &[i64],
    cen: &[i64],
    assign: &mut [i64],
    start: usize,
    end: usize,
    n: usize,
) -> (Vec<i64>, Vec<i64>) {
    let _ = n; // not needed but kept for clarity
    let mut partial_ssum = vec![0i64; K * D];
    let mut partial_cnt = vec![0i64; K];
    for i in start..end {
        let mut best: usize = 0;
        let mut bd: i64 = -1;
        for k in 0..K {
            let mut dist: i64 = 0;
            for d in 0..D {
                let df = pt[i * D + d] - cen[k * D + d];
                dist += df * df;
            }
            if bd < 0 || dist < bd {
                bd = dist;
                best = k;
            }
        }
        assign[i - start] = best as i64;
        partial_cnt[best] += 1;
        for d in 0..D {
            partial_ssum[best * D + d] += pt[i * D + d];
        }
    }
    (partial_ssum, partial_cnt)
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
        .unwrap_or(8000);

    let cores = cores.max(1).min(n);

    let mut pt: Vec<i64> = vec![0; n * D];
    let mut s: i64 = 42;
    for i in 0..n * D {
        s = lcg(s);
        pt[i] = s % RANGE;
    }
    let mut cen: Vec<i64> = vec![0; K * D];
    for i in 0..K * D {
        cen[i] = pt[i];
    }
    let mut assign: Vec<i64> = vec![0; n];

    // Floor-division point bands.
    let bands: Vec<(usize, usize)> = (0..cores)
        .map(|w| (w * n / cores, (w + 1) * n / cores))
        .collect();

    let t0 = std::time::Instant::now();
    for _iter in 0..ITERS {
        // --- PARALLEL ASSIGNMENT ---
        // Each worker gets a disjoint &mut sub-slice of `assign` (via split_at_mut)
        // and RETURNS its partial (ssum, cnt) through the scoped join handle. No raw
        // pointers, no unsafe: &mut [i64] is Send and the handles preserve band order.
        let pt_ref: &[i64] = &pt;
        let cen_ref: &[i64] = &cen;
        let partials: Vec<(Vec<i64>, Vec<i64>)> = std::thread::scope(|scope| {
            let mut handles = Vec::with_capacity(cores);
            let mut remaining: &mut [i64] = &mut assign;
            let mut offset = 0usize;
            for w in 0..cores {
                let (start, end) = bands[w];
                let len = end - offset;
                let (head, tail) = remaining.split_at_mut(len);
                remaining = tail;
                offset = end;
                handles.push(scope.spawn(move || assign_band(pt_ref, cen_ref, head, start, end, n)));
            }
            handles.into_iter().map(|h| h.join().unwrap()).collect()
        });

        // --- SERIAL CENTROID UPDATE ---
        let mut ssum = vec![0i64; K * D];
        let mut cnt = vec![0i64; K];
        for (ps, pc) in &partials {
            for i in 0..K * D {
                ssum[i] += ps[i];
            }
            for k in 0..K {
                cnt[k] += pc[k];
            }
        }
        for k in 0..K {
            if cnt[k] > 0 {
                for d in 0..D {
                    cen[k * D + d] = ssum[k * D + d] / cnt[k];
                }
            }
        }
    }

    // Final assignment with final centroids (parallel, same decomposition).
    {
        let pt_ref: &[i64] = &pt;
        let cen_ref: &[i64] = &cen;
        std::thread::scope(|scope| {
            let mut remaining: &mut [i64] = &mut assign;
            let mut offset = 0usize;
            for w in 0..cores {
                let (start, end) = bands[w];
                let len = end - offset;
                let (head, tail) = remaining.split_at_mut(len);
                remaining = tail;
                offset = end;
                scope.spawn(move || {
                    for i in start..end {
                        let mut best: usize = 0;
                        let mut bd: i64 = -1;
                        for k in 0..K {
                            let mut dist: i64 = 0;
                            for d in 0..D {
                                let df = pt_ref[i * D + d] - cen_ref[k * D + d];
                                dist += df * df;
                            }
                            if bd < 0 || dist < bd {
                                bd = dist;
                                best = k;
                            }
                        }
                        head[i - start] = best as i64;
                    }
                });
            }
        });
    }
    eprintln!("COMPUTE_NS {}", t0.elapsed().as_nanos());

    // Serial checksum (identical to serial k-means).
    let mut h: i64 = 0;
    for i in 0..K * D {
        h = (h * 31 + cen[i]) % P;
    }
    for i in 0..n {
        h = (h * 31 + assign[i]) % P;
    }
    println!("{}", h);
    println!("k-means({})", n);
}
