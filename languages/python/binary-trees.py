import sys


class Node:
    __slots__ = ("left", "right")

    def __init__(self, left, right):
        self.left = left
        self.right = right


def make(depth):
    if depth == 0:
        return Node(None, None)
    return Node(make(depth - 1), make(depth - 1))


def check(node):
    if node.left is None:
        return 1
    return 1 + check(node.left) + check(node.right)


def binary_trees(n):
    min_depth = 4
    max_depth = max(min_depth + 2, n)
    stretch_depth = max_depth + 1

    total = check(make(stretch_depth))
    long_lived = make(max_depth)

    depth = min_depth
    while depth <= max_depth:
        iterations = 1 << (max_depth - depth + min_depth)
        s = 0
        for _ in range(iterations):
            s += check(make(depth))
        total += s
        depth += 2

    total += check(long_lived)
    return total


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 10
    print(binary_trees(n))
    print("binary-trees(%d)" % n)
