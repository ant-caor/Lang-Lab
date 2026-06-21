use strict;
use warnings;

# gbdt: gradient-boosted decision-tree ensemble inference — the dominant tabular-ML
# algorithm (XGBoost/LightGBM/CatBoost style). B=200 trees of depth D=8 over F=8
# features. Each tree is a flat complete binary tree (NODES=511): internal nodes
# 0..254 store a (feature-index, threshold) split; leaves 255..510 store a value.
# Children of node k: left=2k+1, right=2k+2. Inference: for each sample, traverse
# all B trees (exactly D compare-and-branch steps each) and sum the leaf values.
# Checksum: poly-hash of (acc+1) per sample; secondary = sum of acc values mod P.
# LCG draw order pinned: feat then thr per internal node, leafval per leaf, samples.
# All integer — no float, no ML/tree library.

use constant {
    P          => 1000000007,
    D          => 8,
    B          => 200,
    F          => 8,
    NODES      => 511,   # 2^(D+1) - 1
    LEAF_START => 255,   # 2^D - 1
};

my $n = @ARGV ? int($ARGV[0]) : 5000;

my @feat;
my @thr;
my @leafval;

my $state = 42;
for my $b (0 .. B - 1) {
    my $base = $b * NODES;
    for my $node (0 .. LEAF_START - 1) {
        $state = ($state * 1103515245 + 12345) & 0x7fffffff;
        $feat[$base + $node] = $state % F;
        $state = ($state * 1103515245 + 12345) & 0x7fffffff;
        $thr[$base + $node]  = $state % 256;
    }
    for my $node (LEAF_START .. NODES - 1) {
        $state = ($state * 1103515245 + 12345) & 0x7fffffff;
        $leafval[$base + $node] = $state % 10;
    }
}

my @sample;
for my $i (0 .. $n * F - 1) {
    $state = ($state * 1103515245 + 12345) & 0x7fffffff;
    $sample[$i] = $state % 256;
}

my $h     = 0;
my $total = 0;
for my $i (0 .. $n - 1) {
    my $sbase = $i * F;
    my $acc   = 0;
    for my $b (0 .. B - 1) {
        my $tbase = $b * NODES;
        my $node  = 0;
        for (1 .. D) {
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

print "$h\n";
print "gbdt($n) = $total\n";
