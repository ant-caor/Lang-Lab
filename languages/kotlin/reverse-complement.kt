// reverse-complement: generate a DNA sequence, reverse it in place while complementing
// each base (A<->T, C<->G), then reduce it to a polynomial string hash. The reverse uses a
// hand-written two-pointer loop (NOT a stdlib bulk reverse) and the hash a per-character
// loop (NOT a builtin), so this measures the language's own per-character processing -
// consistent with the suite's no-stdlib-shortcut rule. Everything is integer-deterministic.

const val P = 1000000007L
const val IM = 139968L
const val IA = 3877L
const val IC = 29573L

fun comp(c: Char): Char =          // A<->T, C<->G; only A/C/G/T occur
    if (c == 'A') 'T' else if (c == 'C') 'G' else if (c == 'G') 'C' else 'A'

fun reverseComplement(l: Int): Long {
    val s = CharArray(l)           // mutable char buffer
    var seed = 42L
    for (k in 0 until l) {
        seed = (seed * IA + IC) % IM
        s[k] = when {
            seed < 42000 -> 'A'
            seed < 70000 -> 'C'
            seed < 98000 -> 'G'
            else -> 'T'
        }
    }
    var i = 0
    var j = l - 1
    while (i < j) {                // two-pointer reverse-and-complement, in place
        val a = comp(s[i])
        s[i] = comp(s[j])
        s[j] = a
        i++
        j--
    }
    if (i == j) s[i] = comp(s[i])  // middle char when L is odd
    var h = 0L
    for (k in 0 until l) {
        h = (h * 31 + s[k].code.toLong()) % P   // s[k].code is the ASCII byte value
    }
    return h
}

fun main(args: Array<String>) {
    val l = if (args.isNotEmpty()) args[0].toInt() else 100000
    println(reverseComplement(l))
    println("reverse-complement($l)")
}
