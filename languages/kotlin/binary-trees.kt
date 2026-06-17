class Node(val left: Node?, val right: Node?)

fun make(depth: Int): Node {
    if (depth == 0) return Node(null, null)
    return Node(make(depth - 1), make(depth - 1))
}

fun check(node: Node): Long {
    if (node.left == null) return 1L
    return 1L + check(node.left) + check(node.right!!)
}

fun binaryTrees(n: Int): Long {
    val minDepth = 4
    val maxDepth = maxOf(minDepth + 2, n)
    val stretchDepth = maxDepth + 1

    var total = check(make(stretchDepth))
    val longLived = make(maxDepth)

    var depth = minDepth
    while (depth <= maxDepth) {
        val iterations = 1 shl (maxDepth - depth + minDepth)
        var s = 0L
        for (i in 0 until iterations) {
            s += check(make(depth))
        }
        total += s
        depth += 2
    }

    total += check(longLived)
    return total
}

fun main(args: Array<String>) {
    val n = if (args.isNotEmpty()) args[0].toInt() else 10
    println(binaryTrees(n))
    println("binary-trees($n)")
}
