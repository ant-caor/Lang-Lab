<?php

// gbdt: gradient-boosted decision-tree ensemble inference — the dominant tabular-ML
// algorithm (XGBoost/LightGBM/CatBoost style). B=200 trees of depth D=8 over F=8
// features. Each tree is a flat complete binary tree (NODES=511): internal nodes
// 0..254 store a (feature-index, threshold) split; leaves 255..510 store a value.
// Children of node k: left=2k+1, right=2k+2. Inference: for each sample, traverse
// all B trees (exactly D compare-and-branch steps each) and sum the leaf values.
// Checksum: poly-hash of (acc+1) per sample; secondary = sum of acc values mod P.
// LCG draw order pinned: feat then thr per internal node, leafval per leaf, samples.
// All integer — no float, no ML/tree library.

const P          = 1000000007;
const D          = 8;
const B          = 200;
const F          = 8;
const NODES      = 511;  // 2^(D+1) - 1
const LEAF_START = 255;  // 2^D - 1

function gbdt(int $n): array {
    $feat    = array_fill(0, B * NODES, 0);
    $thr     = array_fill(0, B * NODES, 0);
    $leafval = array_fill(0, B * NODES, 0);

    $state = 42;
    for ($b = 0; $b < B; $b++) {
        $base = $b * NODES;
        for ($node = 0; $node < LEAF_START; $node++) {
            $state = ($state * 1103515245 + 12345) & 0x7fffffff;
            $feat[$base + $node] = $state % F;
            $state = ($state * 1103515245 + 12345) & 0x7fffffff;
            $thr[$base + $node]  = $state % 256;
        }
        for ($node = LEAF_START; $node < NODES; $node++) {
            $state = ($state * 1103515245 + 12345) & 0x7fffffff;
            $leafval[$base + $node] = $state % 10;
        }
    }

    $sample = array_fill(0, $n * F, 0);
    for ($i = 0; $i < $n * F; $i++) {
        $state = ($state * 1103515245 + 12345) & 0x7fffffff;
        $sample[$i] = $state % 256;
    }

    $h     = 0;
    $total = 0;
    for ($i = 0; $i < $n; $i++) {
        $sbase = $i * F;
        $acc   = 0;
        for ($b = 0; $b < B; $b++) {
            $tbase = $b * NODES;
            $node  = 0;
            for ($d = 0; $d < D; $d++) {
                if ($sample[$sbase + $feat[$tbase + $node]] <= $thr[$tbase + $node]) {
                    $node = 2 * $node + 1;
                } else {
                    $node = 2 * $node + 2;
                }
            }
            $acc += $leafval[$tbase + $node];
        }
        $h     = ($h * 31 + $acc + 1) % P;
        $total = ($total + $acc)       % P;
    }
    return [$h, $total];
}

$n = isset($argv[1]) ? (int)$argv[1] : 5000;
[$h, $total] = gbdt($n);
echo $h, "\n";
echo "gbdt($n) = $total\n";
