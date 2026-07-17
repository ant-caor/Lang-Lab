class BinaryTrees {
    static final class Node {
        final Node left, right;
        Node(Node left, Node right) { this.left = left; this.right = right; }
    }

    static Node make(int depth) {
        if (depth == 0) return new Node(null, null);
        return new Node(make(depth - 1), make(depth - 1));
    }

    static long check(Node node) {
        if (node.left == null) return 1L;
        return 1L + check(node.left) + check(node.right);
    }

    static long binaryTrees(int n) {
        int minDepth = 4;
        int maxDepth = Math.max(minDepth + 2, n);
        int stretchDepth = maxDepth + 1;

        long total = check(make(stretchDepth));
        Node longLived = make(maxDepth);

        int depth = minDepth;
        while (depth <= maxDepth) {
            int iterations = 1 << (maxDepth - depth + minDepth);
            long s = 0L;
            for (int i = 0; i < iterations; i++) {
                s += check(make(depth));
            }
            total += s;
            depth += 2;
        }

        total += check(longLived);
        return total;
    }

    public static void main(String[] args) {
        int n = args.length > 0 ? Integer.parseInt(args[0]) : 10;
        System.out.println(binaryTrees(n));
        System.out.println("binary-trees(" + n + ")");
    }
}
