// gemm-par: parallel row-band decomposition using DispatchQueue.concurrentPerform.
// Invocation: gemm-par <cores> <n>
// Output: identical to serial gemm for any core count (core-invariant).
//
// Row-band: worker w computes rows [w*N/cores, (w+1)*N/cores).
// A and B are read-only and shared; C rows are disjoint per worker.
// Checksum runs serially after join, identical to serial gemm.
import Foundation

let P = 1000000007

func lcg(_ s: Int) -> Int { return (s &* 1103515245 &+ 12345) & 0x7fffffff }

let args  = CommandLine.arguments
let cores = args.count > 1 ? (Int(args[1]) ?? 1) : 1
let n     = args.count > 2 ? (Int(args[2]) ?? 256) : 256

var A = [Int](repeating: 0, count: n * n)
var B = [Int](repeating: 0, count: n * n)
var C = [Int](repeating: 0, count: n * n)

// LCG init identical to serial gemm
var s = 42
for i in 0..<(n * n) { s = lcg(s); A[i] = s % 128 }
for i in 0..<(n * n) { s = lcg(s); B[i] = s % 128 }

// --- begin timed parallel compute region ---
let _t0 = DispatchTime.now().uptimeNanoseconds

C.withUnsafeMutableBufferPointer { cBuf in
    A.withUnsafeBufferPointer { aBuf in
        B.withUnsafeBufferPointer { bBuf in
            DispatchQueue.concurrentPerform(iterations: cores) { w in
                let rStart = w * n / cores
                let rEnd   = (w + 1) * n / cores
                // Pinned loop order i->k->j, identical to serial gemm.
                for i in rStart..<rEnd {
                    let base = i * n
                    for k in 0..<n {
                        let a  = aBuf[base + k]
                        let kn = k * n
                        for j in 0..<n {
                            cBuf[base + j] += a * bBuf[kn + j]
                        }
                    }
                }
            }
        }
    }
}

let _ns = DispatchTime.now().uptimeNanoseconds - _t0
// --- end timed parallel compute region ---

fputs("COMPUTE_NS \(_ns)\n", stderr)

// Single-threaded checksum pass, row-major, identical to serial gemm.
var h = 0
for i in 0..<(n * n) { h = (h * 31 + C[i] % P) % P }
let secondary = C[n * n - 1] % P

print(h)
print("gemm(\(n)) = \(secondary)")
