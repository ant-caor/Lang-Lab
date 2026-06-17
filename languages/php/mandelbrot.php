<?php

// Mandelbrot set over an N x N grid of the complex plane [-1.5, 0.5] x [-1.0, 1.0].
// A pixel is "in the set" if |z| stays <= 2 (i.e. zr^2+zi^2 <= 4) through 50 iterations
// of z := z^2 + c starting from z = 0. The checksum is the count of in-set pixels.
//
// IEEE-754 double throughout (PHP float is a zend double). The 2*zr*zi term is written
// as t+t (t = zr*zi) instead of 2.0*zr*zi so there is NO multiply-add pattern to
// FMA-contract; t+t is bit-identical to 2.0*t, keeping the result bit-exact everywhere.

function mandelbrot(int $n): int {
    $count = 0;
    for ($y = 0; $y < $n; $y++) {
        $ci = 2.0 * $y / $n - 1.0;
        for ($x = 0; $x < $n; $x++) {
            $cr = 2.0 * $x / $n - 1.5;
            $zr = 0.0;
            $zi = 0.0;
            $tr = 0.0;
            $ti = 0.0;
            $i = 0;
            while ($i < 50 && $tr + $ti <= 4.0) {
                $t = $zr * $zi;
                $zi = $t + $t + $ci;   // == 2*zr*zi + ci, FMA-proof
                $zr = $tr - $ti + $cr;
                $tr = $zr * $zr;
                $ti = $zi * $zi;
                $i++;
            }
            if ($tr + $ti <= 4.0) $count++;   // never escaped -> in set
        }
    }
    return $count;
}

$n = isset($argv[1]) ? (int)$argv[1] : 128;
echo mandelbrot($n), "\n";
echo "mandelbrot($n)\n";
