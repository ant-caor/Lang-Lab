// mandelbrot-par: parallel row-band decomposition using DispatchQueue.concurrentPerform.
// Invocation: mandelbrot-par <cores> <n>
// Output: identical to serial mandelbrot for any core count (core-invariant).
// Workers own disjoint row bands and write their pixel count into a private slot of
// `counts`. withUnsafeMutableBufferPointer pins the array to avoid COW races.
import Foundation

let args  = CommandLine.arguments
let cores = args.count > 1 ? (Int(args[1]) ?? 1) : 1
let n     = args.count > 2 ? (Int(args[2]) ?? 128) : 128

var counts = [Int](repeating: 0, count: cores)

let _t0 = DispatchTime.now().uptimeNanoseconds
counts.withUnsafeMutableBufferPointer { cBuf in
    DispatchQueue.concurrentPerform(iterations: cores) { w in
        let rStart = w * n / cores
        let rEnd   = (w + 1) * n / cores
        var localCount = 0
        for y in rStart..<rEnd {
            let ci = 2.0 * Double(y) / Double(n) - 1.0
            for x in 0..<n {
                let cr = 2.0 * Double(x) / Double(n) - 1.5
                var zr = 0.0, zi = 0.0, tr = 0.0, ti = 0.0
                var i = 0
                while i < 50 && tr + ti <= 4.0 {
                    let t = zr * zi
                    zi = t + t + ci   // FMA-proof: identical to serial
                    zr = tr - ti + cr
                    tr = zr * zr
                    ti = zi * zi
                    i += 1
                }
                if tr + ti <= 4.0 { localCount += 1 }
            }
        }
        cBuf[w] = localCount   // each w is unique; no race
    }
}
let _ns = DispatchTime.now().uptimeNanoseconds - _t0
fputs("COMPUTE_NS \(_ns)\n", stderr)

// Serial sum -- addition is associative and order-independent; result is core-invariant.
var total = 0
for w in 0..<cores { total += counts[w] }

print(total)
print("mandelbrot(\(n))")
