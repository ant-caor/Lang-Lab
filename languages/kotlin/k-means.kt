// k-means: Lloyd's clustering algorithm - the machine-learning axis of the suite. Cluster N
// integer D-dimensional points into K clusters over ITERS fixed iterations: assign each point
// to its nearest centroid (integer squared Euclidean distance), then recompute each centroid as
// the floor-mean of its members. Everything is integer (quantized-style) - deterministic, no
// floating point, so no FMA / summation-order divergence across languages.
//
// Pinned tie-breaks: a point ties to the LOWEST-index centroid (strict < while scanning); an
// empty cluster keeps its centroid unchanged. The checksum hashes the final centroids and the
// final assignment of every point.

const val P = 1000000007L
const val K = 16
const val D = 4
const val ITERS = 10
const val RANGE = 256L

fun kMeans(n: Int): Long {
    val pt = LongArray(n * D)
    var s = 42L
    for (i in 0 until n * D) {
        s = (s * 1103515245L + 12345L) and 0x7fffffffL
        pt[i] = s % RANGE
    }
    val cen = LongArray(K * D)
    for (i in 0 until K * D) cen[i] = pt[i]            // initial centroids = first K points
    val assign = IntArray(n)

    for (iter in 0 until ITERS) {
        for (i in 0 until n) {                         // assignment
            var best = 0
            var bd = -1L
            for (k in 0 until K) {
                var dist = 0L
                for (d in 0 until D) {
                    val df = pt[i * D + d] - cen[k * D + d]
                    dist += df * df
                }
                if (bd < 0 || dist < bd) { bd = dist; best = k }
            }
            assign[i] = best
        }
        val ssum = LongArray(K * D)                    // update: floor-mean, empty unchanged
        val cnt = LongArray(K)
        for (i in 0 until n) {
            val k = assign[i]
            cnt[k]++
            for (d in 0 until D) ssum[k * D + d] += pt[i * D + d]
        }
        for (k in 0 until K) {
            if (cnt[k] > 0) {
                for (d in 0 until D) cen[k * D + d] = ssum[k * D + d] / cnt[k]
            }
        }
    }

    for (i in 0 until n) {                             // final assignment with final centroids
        var best = 0
        var bd = -1L
        for (k in 0 until K) {
            var dist = 0L
            for (d in 0 until D) {
                val df = pt[i * D + d] - cen[k * D + d]
                dist += df * df
            }
            if (bd < 0 || dist < bd) { bd = dist; best = k }
        }
        assign[i] = best
    }

    var h = 0L
    for (i in 0 until K * D) h = (h * 31 + cen[i]) % P
    for (i in 0 until n) h = (h * 31 + assign[i]) % P
    return h
}

fun main(args: Array<String>) {
    val n = if (args.isNotEmpty()) args[0].toInt() else 8000
    println(kMeans(n))
    println("k-means($n)")
}
