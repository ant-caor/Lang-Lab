import Foundation

// blur: a 2D image-convolution benchmark - the stencil axis of the suite. Generate a
// grayscale N x N image, then apply a 3x3 Gaussian blur kernel [1 2 1; 2 4 2; 1 2 1]/16
// PASSES times (double-buffered), with clamp (edge-replication) border handling, and reduce
// the result to a polynomial hash. All integer arithmetic - deterministic, no floating point.

let P = 1000000007
let PASSES = 4

func lcg(_ s: Int) -> Int {
    return (s &* 1103515245 &+ 12345) & 0x7fffffff
}

func clampi(_ x: Int, _ n: Int) -> Int {
    return x < 0 ? 0 : (x >= n ? n - 1 : x)
}

func run(_ N: Int) -> Int {
    let K = [1, 2, 1, 2, 4, 2, 1, 2, 1]   // 3x3, sum 16
    var src = [Int](repeating: 0, count: N * N)
    var dst = [Int](repeating: 0, count: N * N)

    var s = 42
    for k in 0..<(N * N) {
        s = lcg(s)
        src[k] = s % 256
    }

    for _ in 0..<PASSES {
        for i in 0..<N {
            for j in 0..<N {
                var acc = 0
                for di in -1...1 {
                    let ni = clampi(i + di, N)
                    for dj in -1...1 {
                        let nj = clampi(j + dj, N)
                        acc += K[(di + 1) * 3 + (dj + 1)] * src[ni * N + nj]
                    }
                }
                dst[i * N + j] = acc / 16   // integer division
            }
        }
        swap(&src, &dst)                    // double-buffer swap
    }

    var h: Int64 = 0
    let p64 = Int64(P)
    for k in 0..<(N * N) {
        h = (h &* 31 &+ Int64(src[k])) % p64
    }
    return Int(h)
}

let n = CommandLine.arguments.count > 1 ? (Int(CommandLine.arguments[1]) ?? 256) : 256
print(run(n))
print("blur(\(n))")
