import Foundation

let K = 8
let P: Int = 1000000007

func gen(_ L: Int) -> [UInt8] {
    var s = [UInt8](repeating: 0, count: L)
    var seed = 42
    for i in 0..<L {
        seed = (seed * 3877 + 29573) % 139968
        s[i] = seed < 42000 ? UInt8(ascii: "A")
             : seed < 70000 ? UInt8(ascii: "C")
             : seed < 98000 ? UInt8(ascii: "G")
             : UInt8(ascii: "T")
    }
    return s
}

func run(_ L: Int) -> Int {
    let s = gen(L)
    var map = [String: Int]()
    var i = 0
    while i + K <= L {
        let kmer = String(decoding: s[i..<i + K], as: UTF8.self)
        map[kmer, default: 0] += 1
        i += 1
    }
    var acc = 0
    for (kmer, count) in map {
        var e = 0
        for ch in kmer.utf8 {
            let code = ch == UInt8(ascii: "A") ? 0
                     : ch == UInt8(ascii: "C") ? 1
                     : ch == UInt8(ascii: "G") ? 2
                     : 3
            e = e * 4 + code
        }
        acc = (acc + e * count) % P
    }
    return acc
}

let L = CommandLine.arguments.count > 1 ? (Int(CommandLine.arguments[1]) ?? 100000) : 100000
print(run(L))
print("k-nucleotide(\(L))")
