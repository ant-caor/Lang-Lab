<?php

class Node {
    public $left;
    public $right;
    public function __construct($left, $right) {
        $this->left = $left;
        $this->right = $right;
    }
}

function make(int $depth): Node {
    if ($depth === 0) return new Node(null, null);
    return new Node(make($depth - 1), make($depth - 1));
}

function check(Node $node): int {
    if ($node->left === null) return 1;
    return 1 + check($node->left) + check($node->right);
}

function binary_trees(int $n): int {
    $min_depth = 4;
    $max_depth = max($min_depth + 2, $n);
    $stretch_depth = $max_depth + 1;

    $total = check(make($stretch_depth));
    $long_lived = make($max_depth);

    $depth = $min_depth;
    while ($depth <= $max_depth) {
        $iterations = 1 << ($max_depth - $depth + $min_depth);
        $s = 0;
        for ($i = 0; $i < $iterations; $i++) {
            $s += check(make($depth));
        }
        $total += $s;
        $depth += 2;
    }

    $total += check($long_lived);
    return $total;
}

$n = isset($argv[1]) ? (int)$argv[1] : 10;
echo binary_trees($n), "\n";
echo "binary-trees($n)\n";
