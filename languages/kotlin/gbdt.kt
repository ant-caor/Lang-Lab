// gbdt: gradient-boosted decision-tree ensemble inference — the dominant tabular-ML
// algorithm (XGBoost/LightGBM/CatBoost style). B=200 trees of depth D=8 over F=8
// features. Each tree is a flat complete binary tree (NODES=511): internal nodes
// 0..254 store a (feature-index, threshold) split; leaves 255..510 store a value.
// Children of node k: left=2k+1, right=2k+2. Inference: for each sample, traverse
// all B trees (exactly D compare-and-branch steps each) and sum the leaf values.
// Checksum: poly-hash of (acc+1) per sample; secondary = sum of acc values mod P.
// LCG draw order pinned: feat then thr per internal node, leafval per leaf, samples.
// All integer — no float, no ML/tree library.

const val P: Long = 1000000007L
const val D: Int  = 8
const val B: Int  = 200
const val F: Int  = 8
const val NODES: Int      = 511  // 2^(D+1) - 1
const val LEAF_START: Int = 255  // 2^D - 1

fun lcg(s: Long): Long = (s * 1103515245L + 12345L) and 0x7fffffffL

fun gbdt(n: Int): Pair<Long, Long> {
    val feat    = IntArray(B * NODES)
    val thr     = IntArray(B * NODES)
    val leafval = IntArray(B * NODES)

    var s = 42L
    for (b in 0 until B) {
        val base = b * NODES
        for (node in 0 until LEAF_START) {
            s = lcg(s); feat[base + node] = (s % F).toInt()
            s = lcg(s); thr [base + node] = (s % 256).toInt()
        }
        for (node in LEAF_START until NODES) {
            s = lcg(s); leafval[base + node] = (s % 10).toInt()
        }
    }

    val sample = IntArray(n * F)
    for (i in 0 until n * F) {
        s = lcg(s); sample[i] = (s % 256).toInt()
    }

    var h     = 0L
    var total = 0L
    for (i in 0 until n) {
        val sbase = i * F
        var acc   = 0L
        for (b in 0 until B) {
            val tbase = b * NODES
            var node  = 0
            repeat(D) {
                node = if (sample[sbase + feat[tbase + node]] <= thr[tbase + node])
                    2 * node + 1
                else
                    2 * node + 2
            }
            acc += leafval[tbase + node].toLong()
        }
        h     = (h * 31 + acc + 1) % P
        total = (total + acc) % P
    }
    return Pair(h, total)
}

fun main(args: Array<String>) {
    val n = if (args.isNotEmpty()) args[0].toInt() else 5000
    val (h, total) = gbdt(n)
    println(h)
    println("gbdt($n) = $total")
}
