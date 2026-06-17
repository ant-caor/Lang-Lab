using System;

class BinaryTrees
{
    sealed class Node
    {
        public Node Left, Right;
        public Node(Node left, Node right) { Left = left; Right = right; }
    }

    static Node Make(int depth)
    {
        if (depth == 0) return new Node(null, null);
        return new Node(Make(depth - 1), Make(depth - 1));
    }

    static long Check(Node node)
    {
        if (node.Left == null) return 1;
        return 1 + Check(node.Left) + Check(node.Right);
    }

    static long Run(int n)
    {
        int minDepth = 4;
        int maxDepth = Math.Max(minDepth + 2, n);
        int stretchDepth = maxDepth + 1;

        long total = Check(Make(stretchDepth));
        Node longLived = Make(maxDepth);

        int depth = minDepth;
        while (depth <= maxDepth)
        {
            int iterations = 1 << (maxDepth - depth + minDepth);
            long s = 0;
            for (int i = 0; i < iterations; i++) s += Check(Make(depth));
            total += s;
            depth += 2;
        }

        total += Check(longLived);
        return total;
    }

    static void Main(string[] args)
    {
        int n = args.Length > 0 ? int.Parse(args[0]) : 10;
        Console.WriteLine(Run(n));
        Console.WriteLine($"binary-trees({n})");
    }
}
