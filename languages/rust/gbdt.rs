// gbdt: gradient-boosted decision-tree ensemble inference — the dominant tabular-ML
// algorithm (XGBoost/LightGBM/CatBoost style). B=200 trees of depth D=8 over F=8
// features. Each tree is a flat complete binary tree (NODES=511): internal nodes
// 0..254 store a (feature-index, threshold) split; leaves 255..510 store a value.
// Children of node k: left=2k+1, right=2k+2. Inference: for each sample, traverse
// all B trees (exactly D compare-and-branch steps each) and sum the leaf values.
// Checksum: poly-hash of (acc+1) per sample; secondary = sum of acc values mod P.
// LCG draw order pinned: feat then thr per internal node, leafval per leaf, samples.
// All integer — no float, no ML/tree library.
use std::env;

const P: i64 = 1000000007;
const D: usize = 8;
const B: usize = 200;
const F: i32 = 8;
const NODES: usize = 511;      // 2^(D+1) - 1
const LEAF_START: usize = 255; // 2^D - 1

fn lcg(s: i64) -> i64 {
    (s.wrapping_mul(1103515245).wrapping_add(12345)) & 0x7fffffff
}

fn run(n: usize) -> (i64, i64) {
    let mut feat    = vec![0i32; B * NODES];
    let mut thr     = vec![0i32; B * NODES];
    let mut leafval = vec![0i32; B * NODES];

    let mut s: i64 = 42;
    for b in 0..B {
        let base = b * NODES;
        for node in 0..LEAF_START {
            s = lcg(s); feat[base + node] = (s % F as i64) as i32;
            s = lcg(s); thr [base + node] = (s % 256)      as i32;
        }
        for node in LEAF_START..NODES {
            s = lcg(s); leafval[base + node] = (s % 10) as i32;
        }
    }

    let mut sample = vec![0i32; n * F as usize];
    for i in 0..n * F as usize {
        s = lcg(s);
        sample[i] = (s % 256) as i32;
    }

    let mut h: i64 = 0;
    let mut total: i64 = 0;
    for i in 0..n {
        let sbase = i * F as usize;
        let mut acc: i64 = 0;
        for b in 0..B {
            let tbase = b * NODES;
            let mut node: usize = 0;
            for _ in 0..D {
                if sample[sbase + feat[tbase + node] as usize] <= thr[tbase + node] {
                    node = 2 * node + 1;
                } else {
                    node = 2 * node + 2;
                }
            }
            acc += leafval[tbase + node] as i64;
        }
        h     = (h * 31 + acc + 1) % P;
        total = (total + acc) % P;
    }
    (h, total)
}

fn main() {
    let n: usize = env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(5000);
    let (h, total) = run(n);
    println!("{}", h);
    println!("gbdt({}) = {}", n, total);
}
