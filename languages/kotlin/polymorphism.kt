// polymorphism: the dynamic-dispatch / virtual-call-overhead axis of the suite. Build N objects of
// K=6 distinct concrete types in an unpredictable LCG order so the call site stays MEGAMORPHIC (no
// devirtualization / inline-cache wins past the typical <=4 entries), then fold an accumulator
// through all of them M times: acc = obj.apply(acc). Each type has the SAME fields but its OWN
// apply() formula; which one runs is resolved at RUNTIME from the object's type. The acc threads
// through every call (a strict data dependency), so the work cannot be hoisted or precomputed:
// exactly N*M real virtual dispatches happen. The only thing this measures is that dispatch cost.
//
// Kotlin's idiomatic runtime polymorphism: an abstract class with an abstract method, six
// subclasses overriding it, an Array<Apply> of the base type, and a virtual call objs[i].apply(acc).
// NOT a source-level type tag + when/if-chain (that would measure a branch, not a method resolution).

const val P = 1000000007L
const val N = 10000
const val K = 6

// Six distinct per-type transforms (the "virtual method" bodies). All integer, all use x so the
// dependency chain is real; kept tiny so the DISPATCH dominates the per-call cost. Distinct large
// multipliers so the composition over a pass never reaches a fixed point: acc stays chaotic and the
// checksum depends on M (proof that all N*M dispatches ran).
abstract class Apply(val a: Long, val b: Long, val c: Long) {
    abstract fun apply(x: Long): Long
}

class T0(a: Long, b: Long, c: Long) : Apply(a, b, c) {
    override fun apply(x: Long): Long = (x * 1000003L + a) % P
}
class T1(a: Long, b: Long, c: Long) : Apply(a, b, c) {
    override fun apply(x: Long): Long = (x * 998273L + b) % P
}
class T2(a: Long, b: Long, c: Long) : Apply(a, b, c) {
    override fun apply(x: Long): Long = (x * 999983L + c) % P
}
class T3(a: Long, b: Long, c: Long) : Apply(a, b, c) {
    override fun apply(x: Long): Long = (x * 997879L + a + b) % P
}
class T4(a: Long, b: Long, c: Long) : Apply(a, b, c) {
    override fun apply(x: Long): Long = (x * 996323L + b * c) % P
}
class T5(a: Long, b: Long, c: Long) : Apply(a, b, c) {
    override fun apply(x: Long): Long = (x * 995369L + a + c) % P
}

fun lcg(s: Long): Long = (s * 1103515245L + 12345L) and 0x7fffffffL

fun polymorphism(m: Int): Long {
    val objs = arrayOfNulls<Apply>(N)
    var s = 42L
    for (i in 0 until N) {
        s = lcg(s); val t = ((s shr 16) % K).toInt()   // type from HIGH bits (LCG low bits correlate); all K used
        s = lcg(s); val a = s % 1000
        s = lcg(s); val b = s % 1000
        s = lcg(s); val c = s % 1000
        objs[i] = when (t) {
            0 -> T0(a, b, c)
            1 -> T1(a, b, c)
            2 -> T2(a, b, c)
            3 -> T3(a, b, c)
            4 -> T4(a, b, c)
            else -> T5(a, b, c)
        }
    }
    var acc = 1L
    for (pass in 0 until m) {
        for (i in 0 until N) {
            acc = objs[i]!!.apply(acc)   // DYNAMIC dispatch (virtual call per object)
        }
    }
    return acc
}

fun main(args: Array<String>) {
    val m = if (args.isNotEmpty()) args[0].toInt() else 50
    println(polymorphism(m))
    println("polymorphism($m)")
}
