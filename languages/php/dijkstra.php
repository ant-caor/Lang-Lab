<?php

// dijkstra: single-source shortest paths on a deterministically generated weighted
// digraph, using a HAND-WRITTEN binary min-heap (no SplPriorityQueue). The heap stores
// PACKED keys: key = dist * 2^21 + node. Comparing keys as plain integers is exactly the
// (dist, node) lexicographic order, and the keys are all UNIQUE (a node is only re-pushed
// when its distance strictly improves), so the heap behaviour is identical in every
// language. The checksum is a hash of the final distance array. All integer (PHP ints are
// 64-bit signed on 64-bit platforms, which covers INF=2^62, packed keys ~4e12, h ~3e10).

const P = 1000000007;
const BIGINF = 1 << 62;    // 2^62
const DEG = 8;             // average out-degree -> M = DEG*N directed edges
const MAXW = 100;          // edge weights 1..MAXW
const BASE = 2097152;      // 2^21, larger than N; node packs into the low bits

function lcg(int $s): int {
    return ($s * 1103515245 + 12345) & 0x7fffffff;
}

function dijkstra(int $N): int {
    $M = DEG * $N;

    // adjacency in forward (edge-generation) order
    $adjV = array_fill(0, $N, []);
    $adjW = array_fill(0, $N, []);
    $s = 42;
    for ($e = 0; $e < $M; $e++) {
        $s = lcg($s); $u = $s % $N;
        $s = lcg($s); $v = $s % $N;
        $s = lcg($s); $w = $s % MAXW + 1;
        $adjV[$u][] = $v;
        $adjW[$u][] = $w;
    }

    $dist = array_fill(0, $N, BIGINF);
    $dist[0] = 0;

    // hand-written binary min-heap of packed long keys (all keys distinct)
    $heap = [];
    $hsize = 0;

    // push pack(0,0) = 0
    $heap[$hsize++] = 0;

    while ($hsize > 0) {
        // pop_min: hand-written sift-down
        $top = $heap[0];
        $heap[0] = $heap[--$hsize];
        $i = 0;
        while (true) {
            $l = 2 * $i + 1; $r = 2 * $i + 2; $m = $i;
            if ($l < $hsize && $heap[$l] < $heap[$m]) $m = $l;
            if ($r < $hsize && $heap[$r] < $heap[$m]) $m = $r;
            if ($m === $i) break;
            $t = $heap[$m]; $heap[$m] = $heap[$i]; $heap[$i] = $t;
            $i = $m;
        }

        $key = $top;
        $d = intdiv($key, BASE);
        $u = $key % BASE;
        if ($d > $dist[$u]) continue;            // stale heap entry

        $vs = $adjV[$u];
        $ws = $adjW[$u];
        $deg = count($vs);
        for ($j = 0; $j < $deg; $j++) {
            $v = $vs[$j];
            $nd = $d + $ws[$j];
            if ($nd < $dist[$v]) {
                $dist[$v] = $nd;
                // push: hand-written sift-up
                $k = $nd * BASE + $v;
                $i = $hsize++;
                $heap[$i] = $k;
                while ($i > 0) {
                    $p = intdiv($i - 1, 2);
                    if ($heap[$p] <= $heap[$i]) break;
                    $t = $heap[$p]; $heap[$p] = $heap[$i]; $heap[$i] = $t;
                    $i = $p;
                }
            }
        }
    }

    $h = 0;
    for ($i = 0; $i < $N; $i++) {
        $di = $dist[$i] < BIGINF ? $dist[$i] : 0;   // unreachable -> 0
        $h = ($h * 31 + $di % P) % P;
    }
    return $h;
}

$n = isset($argv[1]) ? (int)$argv[1] : 10000;
echo dijkstra($n), "\n";
echo "dijkstra($n)\n";
