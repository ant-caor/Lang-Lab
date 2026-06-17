use strict;
use warnings;
use integer;   # all /, %, & and arithmetic are native 64-bit integer ops

# dijkstra: single-source shortest paths on a deterministically generated weighted
# digraph, using a HAND-WRITTEN binary min-heap (no stdlib priority queue). The heap
# stores PACKED keys: key = dist * 2^21 + node. Comparing keys as plain integers is
# exactly the (dist, node) lexicographic order, and the keys are all UNIQUE, so the
# heap behaviour - and thus the operation count - is identical in every language.

use constant {
    P    => 1000000007,
    INF  => (1 << 62),
    DEG  => 8,            # average out-degree -> M = DEG*N directed edges
    MAXW => 100,          # edge weights 1..MAXW
    BASE => 2097152,      # 2^21, larger than N; node packs into the low bits
};

sub dijkstra {
    my ($N) = @_;
    my $M = DEG * $N;

    # 1. Generate a weighted digraph with the pinned LCG; adjacency in forward
    #    (edge-generation) order: push (v, w) pairs onto the per-node list.
    my @adj = map { [] } 0 .. $N - 1;
    my $s = 42;
    for (my $e = 0; $e < $M; $e++) {
        $s = ($s * 1103515245 + 12345) & 0x7fffffff; my $u = $s % $N;
        $s = ($s * 1103515245 + 12345) & 0x7fffffff; my $v = $s % $N;
        $s = ($s * 1103515245 + 12345) & 0x7fffffff; my $w = $s % MAXW + 1;
        push @{ $adj[$u] }, $v, $w;   # append -> forward order
    }

    # 2. Dijkstra from node 0 with a hand-written binary min-heap of packed keys.
    my @dist = (INF) x $N;
    $dist[0] = 0;

    my @heap;            # array-based binary min-heap of packed long keys
    my $hsize = 0;

    # hpush: append, then sift up while parent > child
    $heap[$hsize] = 0;   # pack(0, 0) = 0
    $hsize++;

    while ($hsize > 0) {
        # hpop: extract-min via hand-written sift-down
        my $key = $heap[0];
        $hsize--;
        $heap[0] = $heap[$hsize];
        my $i = 0;
        while (1) {
            my $l = 2 * $i + 1;
            my $r = 2 * $i + 2;
            my $m = $i;
            $m = $l if $l < $hsize && $heap[$l] < $heap[$m];
            $m = $r if $r < $hsize && $heap[$r] < $heap[$m];
            last if $m == $i;
            ($heap[$m], $heap[$i]) = ($heap[$i], $heap[$m]);
            $i = $m;
        }

        my $d = $key / BASE;     # integer division
        my $u = $key % BASE;     # integer modulo
        next if $d > $dist[$u];  # stale heap entry (lazy deletion)

        my $list = $adj[$u];
        for (my $j = 0; $j < @$list; $j += 2) {
            my $v  = $list->[$j];
            my $nd = $d + $list->[$j + 1];
            if ($nd < $dist[$v]) {
                $dist[$v] = $nd;
                # hpush: append, sift up while parent > child
                my $ci = $hsize;
                $heap[$ci] = $nd * BASE + $v;
                $hsize++;
                while ($ci > 0) {
                    my $pi = ($ci - 1) / 2;
                    last if $heap[$pi] <= $heap[$ci];
                    ($heap[$pi], $heap[$ci]) = ($heap[$ci], $heap[$pi]);
                    $ci = $pi;
                }
            }
        }
    }

    # 3. Checksum: polynomial hash of the distance array (unreachable -> 0).
    my $h = 0;
    for (my $i = 0; $i < $N; $i++) {
        my $di = $dist[$i] < INF ? $dist[$i] : 0;
        $h = ($h * 31 + $di % P) % P;
    }
    return $h;
}

my $n = @ARGV ? int($ARGV[0]) : 10000;
print dijkstra($n), "\n";
print "dijkstra($n)\n";
