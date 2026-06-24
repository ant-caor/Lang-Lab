// gbdt-par: parallel sample-band decomposition using DispatchQueue.concurrentPerform.
// Invocation: gbdt-par <cores> <n>
// Output: identical to serial gbdt for any core count (core-invariant).
//
// Tree arrays (feat/thr/leafval) and sample[] are read-only; all workers share them safely.
// Each worker owns a disjoint band of samples and writes accs[i] for its band.
// withUnsafeMutableBufferPointer pins accs[] to avoid COW races.
// Serial checksum iterates accs[] in index order, identical to serial benchmark.
import Foundation

let P_MOD:     Int = 1000000007
let D_TREE:    Int = 8
let B:         Int = 200
let F:         Int = 8
let NODES:     Int = 511       // 2^(D+1) - 1
let LEAF_START: Int = 255      // 2^D - 1

func lcg(_ s: Int) -> Int { return (s &* 1103515245 &+ 12345) & 0x7fffffff }

let args  = CommandLine.arguments
let cores = args.count > 1 ? (Int(args[1]) ?? 1) : 1
let n     = args.count > 2 ? (Int(args[2]) ?? 5000) : 5000

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
for i in 0..<(n * F) { s = lcg(s); sample[i] = Int32(s % 256) }

var accs = [Int](repeating: 0, count: n)

let _t0 = DispatchTime.now().uptimeNanoseconds
feat.withUnsafeBufferPointer { fBuf in
    thr.withUnsafeBufferPointer { tBuf in
        leafval.withUnsafeBufferPointer { lBuf in
            sample.withUnsafeBufferPointer { sBuf in
                accs.withUnsafeMutableBufferPointer { aBuf in
                    DispatchQueue.concurrentPerform(iterations: cores) { w in
                        let sStart = w * n / cores
                        let sEnd   = (w + 1) * n / cores
                        for i in sStart..<sEnd {
                            let sbase = i * F
                            var acc: Int = 0
                            for b in 0..<B {
                                let tbase = b * NODES
                                var node: Int = 0
                                for _ in 0..<D_TREE {
                                    if sBuf[sbase + Int(fBuf[tbase + node])] <= tBuf[tbase + node] {
                                        node = 2 * node + 1
                                    } else {
                                        node = 2 * node + 2
                                    }
                                }
                                acc += Int(lBuf[tbase + node])
                            }
                            aBuf[i] = acc   // disjoint index; no race
                        }
                    }
                }
            }
        }
    }
}
let _ns = DispatchTime.now().uptimeNanoseconds - _t0
fputs("COMPUTE_NS \(_ns)\n", stderr)

// Serial checksum -- same formula and order as serial benchmark.
var h: Int = 0
var total: Int = 0
for i in 0..<n {
    let acc = accs[i]
    h     = (h * 31 + acc + 1) % P_MOD
    total = (total + acc) % P_MOD
}

print(h)
print("gbdt(\(n)) = \(total)")
