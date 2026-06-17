fun gen(length: Int): String {
    val s = CharArray(length)
    var seed = 42L
    for (i in 0 until length) {
        seed = (seed * 3877 + 29573) % 139968
        s[i] = if (seed < 42000) 'A' else if (seed < 70000) 'C' else if (seed < 98000) 'G' else 'T'
    }
    return String(s)
}

fun kNucleotide(length: Int): Long {
    val k = 8
    val p = 1000000007L
    val s = gen(length)

    val map = HashMap<String, Int>()
    var i = 0
    while (i + k <= length) {
        val kmer = s.substring(i, i + k)
        map[kmer] = (map[kmer] ?: 0) + 1
        i++
    }

    var acc = 0L
    for ((kmer, count) in map) {
        var e = 0L
        for (ch in kmer) {
            val code = when (ch) {
                'A' -> 0
                'C' -> 1
                'G' -> 2
                else -> 3
            }
            e = e * 4 + code
        }
        acc = (acc + e * count) % p
    }
    return acc
}

fun main(args: Array<String>) {
    val n = if (args.isNotEmpty()) args[0].toInt() else 100000
    println(kNucleotide(n))
    println("k-nucleotide($n)")
}
