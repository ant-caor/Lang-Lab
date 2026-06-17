use strict;
use warnings;

# k-means: Lloyd's clustering algorithm - the machine-learning axis of the suite. Cluster
# N integer D-dimensional points into K clusters over ITERS fixed iterations: assign each
# point to its nearest centroid (integer squared Euclidean distance), then recompute each
# centroid as the floor-mean of its members. Everything is integer (quantized-style) - no
# floating point, so no FMA / summation-order divergence across languages. Hand-written
# Lloyd's loops (NO ML/numeric library, NO k-d-tree); @arrays are the flat point/centroid
# storage. Tie-breaks pinned: a point ties to the LOWEST-index centroid (strict < while
# scanning); an empty cluster keeps its centroid unchanged.

use constant {
    P      => 1000000007,
    K      => 16,
    D      => 4,
    ITERS  => 10,
    RANGE  => 256,
};

my $n = @ARGV ? int($ARGV[0]) : 8000;

# 1. Generate N integer D-dimensional points (flat array of length N*D) with the pinned LCG.
my @pt;
my $state = 42;
for my $i (0 .. $n * D - 1) {
    $state = ($state * 1103515245 + 12345) & 0x7fffffff;
    $pt[$i] = $state % RANGE;
}

# Initial centroids = the first K points (flat array of length K*D).
my @cen;
for my $i (0 .. K * D - 1) {
    $cen[$i] = $pt[$i];
}

my @assign;

# 2. ITERS iterations of assign + update.
for (1 .. ITERS) {
    # Assignment: nearest centroid, strict < => ties go to the LOWEST-index centroid.
    for my $i (0 .. $n - 1) {
        my $best = 0;
        my $bd   = -1;
        for my $k (0 .. K - 1) {
            my $dist = 0;
            for my $d (0 .. D - 1) {
                my $df = $pt[$i * D + $d] - $cen[$k * D + $d];   # integer squared distance
                $dist += $df * $df;
            }
            if ($bd < 0 || $dist < $bd) {
                $bd   = $dist;
                $best = $k;
            }
        }
        $assign[$i] = $best;
    }

    # Update: floor-mean of each cluster's members; empty cluster keeps its centroid.
    my @sum = (0) x (K * D);
    my @cnt = (0) x K;
    for my $i (0 .. $n - 1) {
        my $k = $assign[$i];
        $cnt[$k]++;
        for my $d (0 .. D - 1) {
            $sum[$k * D + $d] += $pt[$i * D + $d];
        }
    }
    for my $k (0 .. K - 1) {
        if ($cnt[$k] > 0) {
            for my $d (0 .. D - 1) {
                $cen[$k * D + $d] = int($sum[$k * D + $d] / $cnt[$k]);   # INTEGER (floor) division
            }
        }
        # else: leave centroid[k] unchanged (empty cluster)
    }
}

# 3. Final assignment with the final centroids (same strict-< scan, lowest k on tie).
for my $i (0 .. $n - 1) {
    my $best = 0;
    my $bd   = -1;
    for my $k (0 .. K - 1) {
        my $dist = 0;
        for my $d (0 .. D - 1) {
            my $df = $pt[$i * D + $d] - $cen[$k * D + $d];
            $dist += $df * $df;
        }
        if ($bd < 0 || $dist < $bd) {
            $bd   = $dist;
            $best = $k;
        }
    }
    $assign[$i] = $best;
}

# Checksum: hash the K*D final centroids, then every point's assignment, in that order.
# 64-bit safe in Perl: h*31 ~3.1e10 stays exact within the integer/double range.
my $h = 0;
for my $i (0 .. K * D - 1) {
    $h = ($h * 31 + $cen[$i]) % P;
}
for my $i (0 .. $n - 1) {
    $h = ($h * 31 + $assign[$i]) % P;
}

print "$h\n";
print "k-means($n)\n";
