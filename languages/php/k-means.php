<?php

// k-means: Lloyd's clustering algorithm - the machine-learning axis of the suite. Cluster N
// integer D-dimensional points into K clusters over ITERS fixed iterations: assign each point
// to its nearest centroid (integer squared Euclidean distance), then recompute each centroid as
// the floor-mean of its members. Everything is integer (quantized-style) - deterministic, no
// floating point, so no FMA / summation-order divergence across languages.
//
// Pinned tie-breaks: a point ties to the LOWEST-index centroid (strict < while scanning); an
// empty cluster keeps its centroid unchanged. The checksum hashes the final centroids and the
// final assignment of every point.

const P = 1000000007;
const K = 16;
const D = 4;
const ITERS = 10;
const RANGE = 256;

function k_means(int $n): int {
    // 1. Generate N integer D-dimensional points with the pinned LCG.
    $pt = array_fill(0, $n * D, 0);
    $s = 42;
    for ($i = 0; $i < $n * D; $i++) {
        $s = ($s * 1103515245 + 12345) & 0x7fffffff;
        $pt[$i] = $s % RANGE;
    }

    // Initial centroids = the first K points (copy).
    $cen = array_fill(0, K * D, 0);
    for ($i = 0; $i < K * D; $i++) $cen[$i] = $pt[$i];

    $assign = array_fill(0, $n, 0);

    for ($iter = 0; $iter < ITERS; $iter++) {
        for ($i = 0; $i < $n; $i++) {                 // assignment - nearest centroid
            $best = 0; $bd = -1;
            for ($k = 0; $k < K; $k++) {
                $dist = 0;
                for ($d = 0; $d < D; $d++) {
                    $df = $pt[$i * D + $d] - $cen[$k * D + $d];
                    $dist += $df * $df;
                }
                if ($bd < 0 || $dist < $bd) { $bd = $dist; $best = $k; }
            }
            $assign[$i] = $best;
        }

        $ssum = array_fill(0, K * D, 0);              // update - floor-mean, empty unchanged
        $cnt = array_fill(0, K, 0);
        for ($i = 0; $i < $n; $i++) {
            $k = $assign[$i]; $cnt[$k]++;
            for ($d = 0; $d < D; $d++) $ssum[$k * D + $d] += $pt[$i * D + $d];
        }
        for ($k = 0; $k < K; $k++) {
            if ($cnt[$k] > 0) {
                for ($d = 0; $d < D; $d++) $cen[$k * D + $d] = intdiv($ssum[$k * D + $d], $cnt[$k]);
            }
        }
    }

    for ($i = 0; $i < $n; $i++) {                      // final assignment with final centroids
        $best = 0; $bd = -1;
        for ($k = 0; $k < K; $k++) {
            $dist = 0;
            for ($d = 0; $d < D; $d++) {
                $df = $pt[$i * D + $d] - $cen[$k * D + $d];
                $dist += $df * $df;
            }
            if ($bd < 0 || $dist < $bd) { $bd = $dist; $best = $k; }
        }
        $assign[$i] = $best;
    }

    $h = 0;
    for ($i = 0; $i < K * D; $i++) $h = ($h * 31 + $cen[$i]) % P;
    for ($i = 0; $i < $n; $i++) $h = ($h * 31 + $assign[$i]) % P;
    return $h;
}

$n = isset($argv[1]) ? (int)$argv[1] : 8000;
echo k_means($n), "\n";
echo "k-means($n)\n";
