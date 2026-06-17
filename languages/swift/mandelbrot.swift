// Mandelbrot set over an N x N grid of the complex plane [-1.5, 0.5] x [-1.0, 1.0].
// A pixel is "in the set" if |z| stays <= 2 (i.e. zr^2+zi^2 <= 4) through 50 iterations
// of z := z^2 + c starting from z = 0. The checksum is the count of in-set pixels.
//
// IEEE-754 double (Swift Double) throughout. The 2*zr*zi term is written as t+t (t = zr*zi)
// instead of 2.0*zr*zi so there is NO multiply-add pattern for a compiler to FMA-contract;
// t+t is bit-identical to 2.0*t. This keeps the result bit-exact across every language
// regardless of FMA, fast-math defaults, or auto-vectorization.
import Foundation

func mandel(_ n: Int) -> Int {
    var count = 0
    for y in 0..<n {
        let ci = 2.0 * Double(y) / Double(n) - 1.0
        for x in 0..<n {
            let cr = 2.0 * Double(x) / Double(n) - 1.5
            var zr = 0.0, zi = 0.0, tr = 0.0, ti = 0.0
            var i = 0
            while i < 50 && tr + ti <= 4.0 {
                let t = zr * zi
                zi = t + t + ci   // == 2*zr*zi + ci, FMA-proof
                zr = tr - ti + cr
                tr = zr * zr
                ti = zi * zi
                i += 1
            }
            if tr + ti <= 4.0 { count += 1 }   // never escaped -> in set
        }
    }
    return count
}

let n = CommandLine.arguments.count > 1 ? (Int(CommandLine.arguments[1]) ?? 128) : 128
print(mandel(n))
print("mandelbrot(\(n))")
