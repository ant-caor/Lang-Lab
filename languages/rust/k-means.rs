// k-means: Lloyd's clustering algorithm - the machine-learning axis of the suite. Cluster N
// integer D-dimensional points into K clusters over ITERS fixed iterations: assign each point
// to its nearest centroid (integer squared Euclidean distance), then recompute each centroid as
// the floor-mean of its members. Everything is integer (quantized-style) - deterministic, no
// floating point, so no FMA / summation-order divergence across languages.
//
// Pinned tie-breaks: a point ties to the LOWEST-index centroid (strict < while scanning); an
// empty cluster keeps its centroid unchanged. The checksum hashes the final centroids and the
// final assignment of every point.
use std::env;

const P: i64 = 1000000007;
const K: usize = 16;
const D: usize = 4;
const ITERS: usize = 10;
const RANGE: i64 = 256;

fn lcg(s: i64) -> i64 {
    (s.wrapping_mul(1103515245).wrapping_add(12345)) & 0x7fffffff
}

fn run(n: usize) -> i64 {
    let mut pt: Vec<i64> = vec![0; n * D]; // points
    let mut s: i64 = 42;
    for i in 0..n * D {
        s = lcg(s);
        pt[i] = s % RANGE;
    }
    let mut cen: Vec<i64> = vec![0; K * D];
    for i in 0..K * D {
        cen[i] = pt[i]; // initial centroids = first K points
    }
    let mut assign: Vec<i64> = vec![0; n];

    for _iter in 0..ITERS {
        for i in 0..n {
            // assignment: nearest centroid
            let mut best: usize = 0;
            let mut bd: i64 = -1;
            for k in 0..K {
                let mut dist: i64 = 0;
                for d in 0..D {
                    let df = pt[i * D + d] - cen[k * D + d];
                    dist += df * df;
                }
                if bd < 0 || dist < bd {
                    // STRICT < : ties go to the lowest k
                    bd = dist;
                    best = k;
                }
            }
            assign[i] = best as i64;
        }
        let mut ssum: Vec<i64> = vec![0; K * D]; // update: floor-mean, empty unchanged
        let mut cnt: Vec<i64> = vec![0; K];
        for i in 0..n {
            let k = assign[i] as usize;
            cnt[k] += 1;
            for d in 0..D {
                ssum[k * D + d] += pt[i * D + d];
            }
        }
        for k in 0..K {
            if cnt[k] > 0 {
                for d in 0..D {
                    cen[k * D + d] = ssum[k * D + d] / cnt[k]; // INTEGER (floor) division
                }
            }
        }
    }

    for i in 0..n {
        // final assignment with final centroids
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
        assign[i] = best as i64;
    }

    let mut h: i64 = 0;
    for i in 0..K * D {
        h = (h * 31 + cen[i]) % P;
    }
    for i in 0..n {
        h = (h * 31 + assign[i]) % P;
    }
    h
}

fn main() {
    let n: usize = env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(8000);
    println!("{}", run(n));
    println!("k-means({})", n);
}
