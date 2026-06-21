// viterbi: integer HMM sequence decoding — the classical max-plus trellis.
// S=8 states, ALPHA=4 symbols, T=size parameter. LCG (glibc-style, seed=42)
// draws trans[S*S], emit[S*ALPHA], obs[T] in that order. Forward pass is a
// loop-carried max-reduction (STRICT > tie-break: lowest i wins), followed by
// a pointer-chain backtrace. Checksum = poly-hash of (path[t]+1).
// Secondary = optimal total path score mod P. No HMM library; pure integer.
import Foundation

let S = 8
let ALPHA = 4
let P = 1000000007

func lcg(_ s: Int) -> Int { return (s &* 1103515245 &+ 12345) & 0x7fffffff }

func run(_ t: Int) -> (Int, Int) {
    // Draw order: trans[S*S], emit[S*ALPHA], obs[T]
    var trans = [Int](repeating: 0, count: S * S)
    var emit  = [Int](repeating: 0, count: S * ALPHA)
    var s = 42
    for x in 0..<(S * S)    { s = lcg(s); trans[x] = s % 100 + 1 }
    for x in 0..<(S * ALPHA) { s = lcg(s); emit[x]  = s % 100 + 1 }
    var obs = [Int](repeating: 0, count: t)
    for i in 0..<t { s = lcg(s); obs[i] = s % ALPHA }

    // Initialise t=0
    var vitPrev = [Int](repeating: 0, count: S)
    var vitNext = [Int](repeating: 0, count: S)
    for j in 0..<S { vitPrev[j] = emit[j * ALPHA + obs[0]] }

    var back = [Int](repeating: 0, count: t * S)

    // Forward trellis t=1..T-1
    for ti in 1..<t {
        for j in 0..<S {
            var best = -1; var bi = 0
            let e = emit[j * ALPHA + obs[ti]]
            for i in 0..<S {
                let sc = vitPrev[i] + trans[i * S + j] + e
                if sc > best { best = sc; bi = i }   // STRICT > -> lowest i wins
            }
            vitNext[j] = best
            back[ti * S + j] = bi
        }
        swap(&vitPrev, &vitNext)
    }

    // Final state: STRICT > -> lowest j wins
    var bf = 0
    for j in 1..<S { if vitPrev[j] > vitPrev[bf] { bf = j } }

    // Backtrace
    var path = [Int](repeating: 0, count: t)
    path[t - 1] = bf
    for ti in stride(from: t - 2, through: 0, by: -1) {
        path[ti] = back[(ti + 1) * S + path[ti + 1]]
    }

    // Checksum
    var h = 0
    for ti in 0..<t { h = (h * 31 + path[ti] + 1) % P }
    let secondary = vitPrev[bf] % P
    return (h, secondary)
}

let n = CommandLine.arguments.count > 1 ? (Int(CommandLine.arguments[1]) ?? 20000) : 20000
let (h, sec) = run(n)
print(h)
print("viterbi(\(n)) = \(sec)")
