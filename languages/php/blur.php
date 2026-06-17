<?php

// blur: a 2D image-convolution benchmark - the stencil axis of the suite. Generate a
// grayscale N x N image, then apply a 3x3 Gaussian blur kernel [1 2 1; 2 4 2; 1 2 1]/16
// PASSES times (double-buffered), with clamp (edge-replication) border handling, and reduce
// the result to a polynomial hash. All integer arithmetic - deterministic, no floating point.

const P = 1000000007;
const PASSES = 4;

function lcg(int $s): int {
    return ($s * 1103515245 + 12345) & 0x7fffffff;
}

function clampi(int $x, int $n): int {
    return $x < 0 ? 0 : ($x >= $n ? $n - 1 : $x);
}

function blur(int $n): int {
    $K = [1, 2, 1, 2, 4, 2, 1, 2, 1];   // 3x3, sum 16
    $src = [];
    $dst = [];
    $s = 42;
    for ($k = 0; $k < $n * $n; $k++) {
        $s = lcg($s);
        $src[$k] = $s % 256;
    }
    for ($pass = 0; $pass < PASSES; $pass++) {
        for ($i = 0; $i < $n; $i++) {
            for ($j = 0; $j < $n; $j++) {
                $acc = 0;
                for ($di = -1; $di <= 1; $di++) {
                    $ni = clampi($i + $di, $n);
                    for ($dj = -1; $dj <= 1; $dj++) {
                        $nj = clampi($j + $dj, $n);
                        $acc += $K[($di + 1) * 3 + ($dj + 1)] * $src[$ni * $n + $nj];
                    }
                }
                $dst[$i * $n + $j] = intdiv($acc, 16);   // integer division
            }
        }
        $t = $src; $src = $dst; $dst = $t;               // double-buffer swap
    }
    $h = 0;
    for ($k = 0; $k < $n * $n; $k++) {
        $h = ($h * 31 + $src[$k]) % P;
    }
    return $h;
}

$n = isset($argv[1]) ? (int)$argv[1] : 256;
echo blur($n), "\n";
echo "blur($n)\n";
