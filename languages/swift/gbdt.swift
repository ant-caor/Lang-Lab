// gbdt: gradient-boosted decision-tree ensemble inference — the dominant tabular-ML
// algorithm (XGBoost/LightGBM/CatBoost style). B=200 trees of depth D=8 over F=8
// features. Each tree is a flat complete binary tree (NODES=511): internal nodes
// 0..254 store a (feature-index, threshold) split; leaves 255..510 store a value.
// Children of node k: left=2k+1, right=2k+2. Inference: for each sample, traverse
// all B trees (exactly D compare-and-branch steps each) and sum the leaf values.
// Checksum: poly-hash of (acc+1) per sample; secondary = sum of acc values mod P.
// LCG draw order pinned: feat then thr per internal node, leafval per leaf, samples.
// All integer — no float, no ML/tree library.
import Foundation

let P: Int = 1000000007
let D: Int = 8
let B: Int = 200
let F: Int = 8
let NODES: Int = 511      // 2^(D+1) - 1
let LEAF_START: Int = 255 // 2^D - 1

func lcg(_ s: Int) -> Int { return (s &* 1103515245 &+ 12345) & 0x7fffffff }

func run(_ n: Int) -> (Int, Int) {
    var feat    = [Int32](repeating: 0, count: B * NODES)
    var thr     = [Int32](repeating: 0, count: B * NODES)
    var leafval = [Int32](repeating: 0, count: B * NODES)

    var s = 42
    for b in 0..<B {
        let base = b * NODES
        for node in 0..<LEAF_START {
            s = lcg(s); feat[base + node]    = Int32(s % F)
            s = lcg(s); thr [base + node]    = Int32(s % 256)
        }
        for node in LEAF_START..<NODES {
            s = lcg(s); leafval[base + node] = Int32(s % 10)
        }
    }

    var sample = [Int32](repeating: 0, count: n * F)
    for i in 0..<(n * F) {
        s = lcg(s); sample[i] = Int32(s % 256)
    }

    var h: Int = 0
    var total: Int = 0
    for i in 0..<n {
        let sbase = i * F
        var acc: Int = 0
        for b in 0..<B {
            let tbase = b * NODES
            var node: Int = 0
            for _ in 0..<D {
                if sample[sbase + Int(feat[tbase + node])] <= thr[tbase + node] {
                    node = 2 * node + 1
                } else {
                    node = 2 * node + 2
                }
            }
            acc += Int(leafval[tbase + node])
        }
        h     = (h * 31 + acc + 1) % P
        total = (total + acc) % P
    }
    return (h, total)
}

let n = CommandLine.arguments.count > 1 ? (Int(CommandLine.arguments[1]) ?? 5000) : 5000
let (h, total) = run(n)
print(h)
print("gbdt(\(n)) = \(total)")
