// gemm: quantized integer matrix-multiply - the dominant ML inference kernel.
// Square matmul of side N (i.e. N x N matrices). Loop order i,k,j (pinned)
// so B is accessed row-sequentially. LCG fills A then B with values 0..127.
// Accumulator is 64-bit; checksum = poly-hash of C row-major mod 1e9+7.
// No BLAS / no library matmul - the explicit triple loop.
import Foundation

let P = 1000000007

func lcg(_ s: Int) -> Int { return (s &* 1103515245 &+ 12345) & 0x7fffffff }

func run(_ n: Int) -> (Int, Int) {
    var A = [Int](repeating: 0, count: n * n)
    var B = [Int](repeating: 0, count: n * n)
    var C = [Int](repeating: 0, count: n * n)

    var s = 42
    for i in 0..<(n * n) { s = lcg(s); A[i] = s % 128 }
    for i in 0..<(n * n) { s = lcg(s); B[i] = s % 128 }

    // Pinned loop order i, k, j - B read row-sequentially.
    for i in 0..<n {
        for k in 0..<n {
            let a = A[i * n + k]
            let kn = k * n
            let base = i * n
            for j in 0..<n {
                C[base + j] += a * B[kn + j]
            }
        }
    }

    var h = 0
    for i in 0..<(n * n) { h = (h * 31 + C[i] % P) % P }
    let secondary = C[n * n - 1] % P
    return (h, secondary)
}

let n = CommandLine.arguments.count > 1 ? (Int(CommandLine.arguments[1]) ?? 256) : 256
let (h, sec) = run(n)
print(h)
print("gemm(\(n)) = \(sec)")
