// polymorphism: the dynamic-dispatch / virtual-call-overhead axis of the suite. Build N=10000
// objects of K=6 concrete types in an unpredictable LCG order (the call site is MEGAMORPHIC, so
// the JIT cannot devirtualize / inline-cache it), then fold an accumulator through all of them M
// times: acc = obj.apply(acc). Every type shares the same fields a,b,c but has its OWN apply()
// formula; which one runs is resolved at RUNTIME by the object's concrete type. The acc threads
// through every call (a strict data dependency), so the N*M dispatches cannot be hoisted.
//
// Scala uses idiomatic runtime polymorphism: a trait with an abstract method + six final
// subclasses, held in an Array[Apply] of the base type -> a real virtual (interface) dispatch per
// object. NOT a type tag + match (that would measure a branch, which is forbidden by the spec).
// All integer, mod 1e9+7; checksum = the final accumulator.
object Polymorphism {
  final val P = 1000000007L
  final val N = 10000
  final val K = 6

  // The "vtable": one abstract method, six distinct per-type bodies. Distinct large multipliers
  // keep the per-pass composition chaotic (never a fixed point), so the checksum depends on M.
  abstract class Apply(val a: Long, val b: Long, val c: Long) {
    def apply(x: Long): Long
  }
  final class T0(a: Long, b: Long, c: Long) extends Apply(a, b, c) {
    def apply(x: Long): Long = (x * 1000003L + a) % P
  }
  final class T1(a: Long, b: Long, c: Long) extends Apply(a, b, c) {
    def apply(x: Long): Long = (x * 998273L + b) % P
  }
  final class T2(a: Long, b: Long, c: Long) extends Apply(a, b, c) {
    def apply(x: Long): Long = (x * 999983L + c) % P
  }
  final class T3(a: Long, b: Long, c: Long) extends Apply(a, b, c) {
    def apply(x: Long): Long = (x * 997879L + a + b) % P
  }
  final class T4(a: Long, b: Long, c: Long) extends Apply(a, b, c) {
    def apply(x: Long): Long = (x * 996323L + b * c) % P
  }
  final class T5(a: Long, b: Long, c: Long) extends Apply(a, b, c) {
    def apply(x: Long): Long = (x * 995369L + a + c) % P
  }

  // glibc-style LCG (constants exceed Int range -> Long arithmetic); type from the HIGH bits
  // (the low bits correlate), fields mod 1000.
  def lcg(s: Long): Long = (s * 1103515245L + 12345L) & 0x7fffffffL

  def run(m: Int): Long = {
    val objs = new Array[Apply](N)
    var s = 42L
    var i = 0
    while (i < N) {
      s = lcg(s); val t = ((s >> 16) % K).toInt   // type from HIGH bits; all K used -> megamorphic
      s = lcg(s); val a = s % 1000
      s = lcg(s); val b = s % 1000
      s = lcg(s); val c = s % 1000
      objs(i) = (t: @annotation.switch) match {
        case 0 => new T0(a, b, c)
        case 1 => new T1(a, b, c)
        case 2 => new T2(a, b, c)
        case 3 => new T3(a, b, c)
        case 4 => new T4(a, b, c)
        case _ => new T5(a, b, c)
      }
      i += 1
    }
    var acc = 1L
    var pass = 0
    while (pass < m) {
      var j = 0
      while (j < N) { acc = objs(j).apply(acc); j += 1 }   // DYNAMIC dispatch (virtual call)
      pass += 1
    }
    acc
  }

  def main(args: Array[String]): Unit = {
    val m = if (args.nonEmpty) args(0).toInt else 50
    println(run(m))
    println(s"polymorphism($m)")
  }
}
