object BinaryTrees {
  final class Node(val left: Node, val right: Node)

  def make(depth: Int): Node = {
    if (depth == 0) new Node(null, null)
    else new Node(make(depth - 1), make(depth - 1))
  }

  def check(node: Node): Long = {
    if (node.left == null) 1L
    else 1L + check(node.left) + check(node.right)
  }

  def binaryTrees(n: Int): Long = {
    val minDepth = 4
    val maxDepth = math.max(minDepth + 2, n)
    val stretchDepth = maxDepth + 1

    var total = check(make(stretchDepth))
    val longLived = make(maxDepth)

    var depth = minDepth
    while (depth <= maxDepth) {
      val iterations = 1 << (maxDepth - depth + minDepth)
      var s = 0L
      var i = 0
      while (i < iterations) { s += check(make(depth)); i += 1 }
      total += s
      depth += 2
    }

    total += check(longLived)
    total
  }

  def main(args: Array[String]): Unit = {
    val n = if (args.nonEmpty) args(0).toInt else 10
    println(binaryTrees(n))
    println(s"binary-trees($n)")
  }
}
