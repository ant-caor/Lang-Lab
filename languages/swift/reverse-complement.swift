// reverse-complement: generate a DNA sequence, reverse it in place while complementing
// each base (A<->T, C<->G), then reduce it to a polynomial string hash. The reverse uses a
// hand-written two-pointer loop (NOT a stdlib bulk reverse) and the hash a per-character
// loop (NOT a builtin), so this measures the language's own per-character processing -
// consistent with the suite's no-stdlib-shortcut rule. Everything is integer-deterministic.
import Foundation

let P: Int = 1000000007
let IM: Int = 139968
let IA: Int = 3877
let IC: Int = 29573

// ASCII byte values: A=65, C=67, G=71, T=84
let A: UInt8 = 65
let C: UInt8 = 67
let G: UInt8 = 71
let T: UInt8 = 84

func comp(_ c: UInt8) -> UInt8 {    // A<->T, C<->G; only A/C/G/T occur
    if c == A { return T }
    if c == C { return G }
    if c == G { return C }
    return A
}

func run(_ L: Int) -> Int {
    var s = [UInt8](repeating: 0, count: L)
    var seed = 42
    for i in 0..<L {
        seed = (seed * IA + IC) % IM
        s[i] = seed < 42000 ? A : seed < 70000 ? C : seed < 98000 ? G : T
    }
    var i = 0, j = L - 1
    while i < j {                    // two-pointer reverse-and-complement, in place
        let a = comp(s[i])
        s[i] = comp(s[j])
        s[j] = a
        i += 1; j -= 1
    }
    if i == j { s[i] = comp(s[i]) }  // middle char when L is odd
    var h = 0
    for k in 0..<L {
        h = (h * 31 + Int(s[k])) % P
    }
    return h
}

let L = CommandLine.arguments.count > 1 ? (Int(CommandLine.arguments[1]) ?? 100000) : 100000
print(run(L))
print("reverse-complement(\(L))")
