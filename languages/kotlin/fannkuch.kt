fun fannkuch(n: Int): Pair<Int, Int> {
    val perm1 = IntArray(n) { it }
    val perm = IntArray(n)
    val count = IntArray(n)
    var maxFlips = 0
    var checksum = 0
    var permIdx = 0L  // counts up to n!-1 → needs 64-bit for n >= 13
    var r = n

    while (true) {
        while (r != 1) {
            count[r - 1] = r
            r--
        }

        System.arraycopy(perm1, 0, perm, 0, n)
        var flips = 0
        var k = perm[0]
        while (k != 0) {
            var i = 0
            var j = k
            while (i < j) {
                val t = perm[i]; perm[i] = perm[j]; perm[j] = t
                i++; j--
            }
            flips++
            k = perm[0]
        }

        if (flips > maxFlips) maxFlips = flips
        checksum += if (permIdx % 2 == 0L) flips else -flips

        // Generate the next permutation.
        while (true) {
            if (r == n) return Pair(maxFlips, checksum)
            val first = perm1[0]
            for (i in 0 until r) perm1[i] = perm1[i + 1]
            perm1[r] = first
            count[r]--
            if (count[r] > 0) break
            r++
        }
        permIdx++
    }
}

fun main(args: Array<String>) {
    val n = if (args.isNotEmpty()) args[0].toInt() else 7
    val (maxFlips, checksum) = fannkuch(n)
    println(checksum)
    println("Pfannkuchen($n) = $maxFlips")
}
