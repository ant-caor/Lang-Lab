// blur-par: parallel row-band decomposition using DispatchQueue.concurrentPerform.
// Invocation: blur-par <cores> <n>
// Output: identical to serial blur for any core count (core-invariant).
//
// Per pass: srcSnap is an immutable copy of src (safe concurrent reads).
// Workers write disjoint rows of dst via withUnsafeMutableBufferPointer (pins array,
// avoids COW). Buffers are swapped serially between passes, identical to serial.
import Foundation

let P_MOD  = 1000000007
let PASSES = 4

func lcg(_ s: Int) -> Int { return (s &* 1103515245 &+ 12345) & 0x7fffffff }
func clampi(_ x: Int, _ n: Int) -> Int { return x < 0 ? 0 : (x >= n ? n - 1 : x) }

let args  = CommandLine.arguments
let cores = args.count > 1 ? (Int(args[1]) ?? 1) : 1
let n     = args.count > 2 ? (Int(args[2]) ?? 256) : 256

let K = [1, 2, 1, 2, 4, 2, 1, 2, 1]   // 3x3 Gaussian kernel, sum 16

var src = [Int](repeating: 0, count: n * n)
var dst = [Int](repeating: 0, count: n * n)

var s = 42
for k in 0..<(n * n) { s = lcg(s); src[k] = s % 256 }

let _t0 = DispatchTime.now().uptimeNanoseconds
for _ in 0..<PASSES {
    // Immutable copy of src: all workers read from srcSnap, no write-read race.
    let srcSnap = src
    dst.withUnsafeMutableBufferPointer { dBuf in
        srcSnap.withUnsafeBufferPointer { sBuf in
            DispatchQueue.concurrentPerform(iterations: cores) { w in
                let rStart = w * n / cores
                let rEnd   = (w + 1) * n / cores
                for i in rStart..<rEnd {
                    for j in 0..<n {
                        var acc = 0
                        for di in -1...1 {
                            let ni = clampi(i + di, n)
                            for dj in -1...1 {
                                let nj = clampi(j + dj, n)
                                acc += K[(di + 1) * 3 + (dj + 1)] * sBuf[ni * n + nj]
                            }
                        }
                        dBuf[i * n + j] = acc / 16   // disjoint rows; no race
                    }
                }
            }
        }
    }
    swap(&src, &dst)   // serial double-buffer swap, identical to serial benchmark
}
let _ns = DispatchTime.now().uptimeNanoseconds - _t0
fputs("COMPUTE_NS \(_ns)\n", stderr)

var h: Int64 = 0
let p64 = Int64(P_MOD)
for k in 0..<(n * n) { h = (h &* 31 &+ Int64(src[k])) % p64 }

print(Int(h))
print("blur(\(n))")
