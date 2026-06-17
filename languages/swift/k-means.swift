// k-means: Lloyd's clustering algorithm - the machine-learning axis of the suite. Cluster N
// integer D-dimensional points into K clusters over ITERS fixed iterations: assign each point
// to its nearest centroid (integer squared Euclidean distance), then recompute each centroid as
// the floor-mean of its members. Everything is integer (quantized-style) - deterministic, no
// floating point, so no FMA / summation-order divergence across languages.
//
// Pinned tie-breaks: a point ties to the LOWEST-index centroid (strict < while scanning); an
// empty cluster keeps its centroid unchanged. The checksum hashes the final centroids and the
// final assignment of every point.
import Foundation

let P = 1000000007
let K = 16
let D = 4
let ITERS = 10
let RANGE = 256

func lcg(_ s: Int) -> Int { return (s &* 1103515245 &+ 12345) & 0x7fffffff }

func run(_ N: Int) -> Int {
    var pt = [Int](repeating: 0, count: N * D)      // points
    var s = 42
    for i in 0..<(N * D) { s = lcg(s); pt[i] = s % RANGE }
    var cen = [Int](repeating: 0, count: K * D)     // initial centroids = first K points
    for i in 0..<(K * D) { cen[i] = pt[i] }
    var assign = [Int](repeating: 0, count: N)

    for _ in 0..<ITERS {
        for i in 0..<N {                            // assignment
            var best = 0; var bd = -1
            for k in 0..<K {
                var dist = 0
                for d in 0..<D { let df = pt[i * D + d] - cen[k * D + d]; dist += df * df }
                if bd < 0 || dist < bd { bd = dist; best = k }
            }
            assign[i] = best
        }
        var ssum = [Int](repeating: 0, count: K * D)    // update: floor-mean, empty unchanged
        var cnt = [Int](repeating: 0, count: K)
        for i in 0..<N {
            let k = assign[i]; cnt[k] += 1
            for d in 0..<D { ssum[k * D + d] += pt[i * D + d] }
        }
        for k in 0..<K where cnt[k] > 0 {
            for d in 0..<D { cen[k * D + d] = ssum[k * D + d] / cnt[k] }
        }
    }

    for i in 0..<N {                                // final assignment with final centroids
        var best = 0; var bd = -1
        for k in 0..<K {
            var dist = 0
            for d in 0..<D { let df = pt[i * D + d] - cen[k * D + d]; dist += df * df }
            if bd < 0 || dist < bd { bd = dist; best = k }
        }
        assign[i] = best
    }

    var h = 0
    for i in 0..<(K * D) { h = (h * 31 + cen[i]) % P }
    for i in 0..<N { h = (h * 31 + assign[i]) % P }
    return h
}

let n = CommandLine.arguments.count > 1 ? (Int(CommandLine.arguments[1]) ?? 8000) : 8000
print(run(n))
print("k-means(\(n))")
