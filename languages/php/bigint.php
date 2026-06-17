<?php

// bigint: hand-rolled multi-precision arithmetic - the carry-propagation axis. Compute N! as an
// array of base-2^32 limbs by repeated bignum*smallint multiplication (each limb: cur = limb*k +
// carry; store low 32 bits, propagate the high bits), then poly-hash the limbs. Implemented by hand
// (NO native/library big integers - PHP has no bignum here, the limb array IS the big number), so it
// measures raw multi-word arithmetic. All integer-deterministic. PHP ints are 64-bit, so the
// intermediate cur (~2^46 for these N) fits without overflow.

const P = 1000000007;

function bigint(int $n): int {
    $limbs = [1];                              // least-significant limb first; base 2^32
    $len = 1;
    for ($k = 2; $k <= $n; $k++) {
        $carry = 0;
        for ($i = 0; $i < $len; $i++) {
            $cur = $limbs[$i] * $k + $carry;   // 64-bit intermediate (reaches ~2^46)
            $limbs[$i] = $cur & 0xFFFFFFFF;    // low 32 bits
            $carry = $cur >> 32;               // high bits propagate
        }
        while ($carry > 0) {
            $limbs[$len++] = $carry & 0xFFFFFFFF;
            $carry >>= 32;
        }
    }

    $h = 0;
    for ($i = 0; $i < $len; $i++) {            // poly-hash least-significant first
        $h = ($h * 31 + $limbs[$i]) % P;
    }
    return $h;
}

$n = isset($argv[1]) ? (int)$argv[1] : 6000;
echo bigint($n), "\n";
echo "bigint($n)\n";
