// k-means-par: parallel point-band assignment using DispatchQueue.concurrentPerform.
// Invocation: k-means-par <cores> <n>
// Output: identical to serial k-means for any core count (core-invariant).
//
// ASSIGNMENT step: workers own disjoint bands of points; each writes assign[i] for its
// band, and accumulates into per-worker partial sums/counts at disjoint offsets.
// UPDATE step: serial merge of all partial sums/counts -> updated centroids (floor-mean,
// empty-cluster unchanged), identical to serial benchmark.
// Tie-break: strict < lowest-index, preserved (points processed in original order).
import Foundation

let P_MOD = 1000000007
let K_CL  = 16
let D     = 4
let ITERS = 10
let RANGE = 256

func lcg(_ s: Int) -> Int { return (s &* 1103515245 &+ 12345) & 0x7fffffff }

let args  = CommandLine.arguments
let cores = args.count > 1 ? (Int(args[1]) ?? 1) : 1
let n     = args.count > 2 ? (Int(args[2]) ?? 8000) : 8000

var pt = [Int](repeating: 0, count: n * D)
var s  = 42
for i in 0..<(n * D) { s = lcg(s); pt[i] = s % RANGE }

var cen    = [Int](repeating: 0, count: K_CL * D)
var assign = [Int](repeating: 0, count: n)
for i in 0..<(K_CL * D) { cen[i] = pt[i] }

// Per-worker partial accumulators: worker w owns [w*K_CL*D .. (w+1)*K_CL*D) of ssum
// and [w*K_CL .. (w+1)*K_CL) of cnt.
var partialSsum = [Int](repeating: 0, count: cores * K_CL * D)
var partialCnt  = [Int](repeating: 0, count: cores * K_CL)

let _t0 = DispatchTime.now().uptimeNanoseconds
for _ in 0..<ITERS {
    // --- PARALLEL ASSIGNMENT ---
    let cenSnap = cen   // immutable snapshot; safe for concurrent reads
    pt.withUnsafeBufferPointer { ptBuf in
        assign.withUnsafeMutableBufferPointer { aBuf in
            partialSsum.withUnsafeMutableBufferPointer { ssBuf in
                partialCnt.withUnsafeMutableBufferPointer { cntBuf in
                    DispatchQueue.concurrentPerform(iterations: cores) { w in
                        let ptStart   = w * n / cores
                        let ptEnd     = (w + 1) * n / cores
                        let wSsumBase = w * K_CL * D
                        let wCntBase  = w * K_CL
                        // Reset this worker's partial accumulators.
                        for k in 0..<K_CL {
                            cntBuf[wCntBase + k] = 0
                            for d in 0..<D { ssBuf[wSsumBase + k * D + d] = 0 }
                        }
                        for i in ptStart..<ptEnd {
                            var best = 0; var bd = -1
                            for k in 0..<K_CL {
                                var dist = 0
                                for d in 0..<D {
                                    let df = ptBuf[i * D + d] - cenSnap[k * D + d]
                                    dist += df * df
                                }
                                if bd < 0 || dist < bd { bd = dist; best = k }
                            }
                            aBuf[i] = best   // disjoint index; no race
                            cntBuf[wCntBase + best] += 1
                            for d in 0..<D { ssBuf[wSsumBase + best * D + d] += ptBuf[i * D + d] }
                        }
                    }
                }
            }
        }
    }

    // --- SERIAL UPDATE ---
    var ssum = [Int](repeating: 0, count: K_CL * D)
    var cnt  = [Int](repeating: 0, count: K_CL)
    for w in 0..<cores {
        let wSsumBase = w * K_CL * D
        let wCntBase  = w * K_CL
        for k in 0..<K_CL {
            cnt[k] += partialCnt[wCntBase + k]
            for d in 0..<D { ssum[k * D + d] += partialSsum[wSsumBase + k * D + d] }
        }
    }
    for k in 0..<K_CL where cnt[k] > 0 {
        for d in 0..<D { cen[k * D + d] = ssum[k * D + d] / cnt[k] }
    }
}

// Final assignment with final centroids -- serial, identical to serial benchmark.
let cenFinal = cen
pt.withUnsafeBufferPointer { ptBuf in
    assign.withUnsafeMutableBufferPointer { aBuf in
        for i in 0..<n {
            var best = 0; var bd = -1
            for k in 0..<K_CL {
                var dist = 0
                for d in 0..<D {
                    let df = ptBuf[i * D + d] - cenFinal[k * D + d]; dist += df * df
                }
                if bd < 0 || dist < bd { bd = dist; best = k }
            }
            aBuf[i] = best
        }
    }
}
let _ns = DispatchTime.now().uptimeNanoseconds - _t0
fputs("COMPUTE_NS \(_ns)\n", stderr)

var h = 0
for i in 0..<(K_CL * D) { h = (h * 31 + cen[i]) % P_MOD }
for i in 0..<n            { h = (h * 31 + assign[i]) % P_MOD }

print(h)
print("k-means(\(n))")
