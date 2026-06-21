// viterbi: integer HMM sequence decoding — the classical max-plus trellis.
// S=8 states, ALPHA=4 symbols, T=size parameter. LCG (glibc-style, seed=42)
// draws trans[S*S], emit[S*ALPHA], obs[T] in that order. Forward pass is a
// loop-carried max-reduction (STRICT > tie-break: lowest i wins), followed by
// a pointer-chain backtrace. Checksum = poly-hash of (path[t]+1).
// Secondary = optimal total path score mod P. No HMM library; pure integer.

const val S_VIT = 8
const val ALPHA_VIT = 4
const val P_VIT = 1000000007L

fun viterbi(t: Int): Pair<Long, Long> {
    // Draw order: trans[S*S], emit[S*ALPHA], obs[T]
    val trans = LongArray(S_VIT * S_VIT)
    val emit  = LongArray(S_VIT * ALPHA_VIT)
    val obs   = IntArray(t)
    var s = 42L
    for (x in 0 until S_VIT * S_VIT) {
        s = (s * 1103515245L + 12345L) and 0x7fffffffL
        trans[x] = s % 100L + 1L
    }
    for (x in 0 until S_VIT * ALPHA_VIT) {
        s = (s * 1103515245L + 12345L) and 0x7fffffffL
        emit[x] = s % 100L + 1L
    }
    for (i in 0 until t) {
        s = (s * 1103515245L + 12345L) and 0x7fffffffL
        obs[i] = (s % ALPHA_VIT).toInt()
    }

    // Initialise t=0
    var vitPrev = LongArray(S_VIT) { emit[it * ALPHA_VIT + obs[0]] }
    var vitNext = LongArray(S_VIT)

    val back = IntArray(t * S_VIT)

    // Forward trellis t=1..T-1
    for (ti in 1 until t) {
        for (j in 0 until S_VIT) {
            var best = -1L; var bi = 0
            val e = emit[j * ALPHA_VIT + obs[ti]]
            for (i in 0 until S_VIT) {
                val sc = vitPrev[i] + trans[i * S_VIT + j] + e
                if (sc > best) { best = sc; bi = i }   // STRICT > -> lowest i wins
            }
            vitNext[j] = best
            back[ti * S_VIT + j] = bi
        }
        val tmp = vitPrev; vitPrev = vitNext; vitNext = tmp
    }

    // Final state: STRICT > -> lowest j wins
    var bf = 0
    for (j in 1 until S_VIT) { if (vitPrev[j] > vitPrev[bf]) bf = j }

    // Backtrace
    val path = IntArray(t)
    path[t - 1] = bf
    for (ti in t - 2 downTo 0) path[ti] = back[(ti + 1) * S_VIT + path[ti + 1]]

    // Checksum
    var h = 0L
    for (ti in 0 until t) h = (h * 31L + path[ti] + 1L) % P_VIT

    val secondary = vitPrev[bf] % P_VIT
    return Pair(h, secondary)
}

fun main(args: Array<String>) {
    val t = if (args.isNotEmpty()) args[0].toInt() else 20000
    val (h, sec) = viterbi(t)
    println(h)
    println("viterbi($t) = $sec")
}
