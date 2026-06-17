object ReverseComplement {
  final val P  = 1000000007L
  final val IM = 139968L
  final val IA = 3877L
  final val IC = 29573L

  def comp(c: Byte): Byte =            // A<->T, C<->G; only A/C/G/T occur
    if (c == 'A') 'T' else if (c == 'C') 'G' else if (c == 'G') 'C' else 'A'

  def reverseComplement(L: Int): Long = {
    val s = new Array[Byte](L)
    var seed = 42L
    var i = 0
    while (i < L) {
      seed = (seed * IA + IC) % IM
      s(i) =
        if (seed < 42000) 'A'
        else if (seed < 70000) 'C'
        else if (seed < 98000) 'G'
        else 'T'
      i += 1
    }

    i = 0
    var j = L - 1
    while (i < j) {                    // two-pointer reverse-and-complement, in place
      val a = comp(s(i))
      s(i) = comp(s(j))
      s(j) = a
      i += 1; j -= 1
    }
    if (i == j) s(i) = comp(s(i))      // middle char when L is odd

    var h = 0L
    var k = 0
    while (k < L) {
      h = (h * 31 + (s(k) & 0xff)) % P // ASCII byte value: A=65, C=67, G=71, T=84
      k += 1
    }
    h
  }

  def main(args: Array[String]): Unit = {
    val L = if (args.nonEmpty) args(0).toInt else 100000
    println(reverseComplement(L))
    println(s"reverse-complement($L)")
  }
}
