import Foundation

final class Node {
    let left: Node?
    let right: Node?
    init(_ left: Node?, _ right: Node?) {
        self.left = left
        self.right = right
    }
}

func make(_ depth: Int) -> Node {
    if depth == 0 {
        return Node(nil, nil)
    }
    return Node(make(depth - 1), make(depth - 1))
}

func check(_ node: Node) -> Int {
    if node.left == nil {
        return 1
    }
    return 1 + check(node.left!) + check(node.right!)
}

func run(_ n: Int) -> Int {
    let minDepth = 4
    let maxDepth = max(minDepth + 2, n)
    let stretchDepth = maxDepth + 1

    var total = check(make(stretchDepth))
    let longLived = make(maxDepth)

    var depth = minDepth
    while depth <= maxDepth {
        let iterations = 1 << (maxDepth - depth + minDepth)
        var s = 0
        for _ in 0..<iterations {
            s += check(make(depth))
        }
        total += s
        depth += 2
    }

    total += check(longLived)
    return total
}

let n = CommandLine.arguments.count > 1 ? (Int(CommandLine.arguments[1]) ?? 10) : 10
print(run(n))
print("binary-trees(\(n))")
