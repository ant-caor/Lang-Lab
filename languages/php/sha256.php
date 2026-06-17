<?php

// sha256: iterated SHA-256 - real FIPS 180-4, applied N times to a 32-byte LCG digest.
// Hand-written (no crypto library); every word is unsigned 32-bit, so every add and shift
// is masked with & 0xFFFFFFFF (PHP ints are 64-bit, so a masked value's >> is logical).

const P = 1000000007;

const K = [
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
];

const H0 = [
    0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,
    0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19,
];

function rotr(int $x, int $n): int {
    return (($x >> $n) | ($x << (32 - $n))) & 0xFFFFFFFF;
}

// hash the 32-byte digest in place (one padded 64-byte block; message length = 256 bits)
function sha256_32(array &$digest): void {
    // build the padded 64-byte block
    $b = array_fill(0, 64, 0);
    for ($i = 0; $i < 32; $i++) $b[$i] = $digest[$i];
    $b[32] = 0x80;
    $b[62] = 1;                                 // length 256 = 0x0100

    // 16 big-endian words
    $w = array_fill(0, 64, 0);
    for ($i = 0; $i < 16; $i++) {
        $w[$i] = (($b[$i*4] << 24) | ($b[$i*4+1] << 16) | ($b[$i*4+2] << 8) | $b[$i*4+3]) & 0xFFFFFFFF;
    }
    for ($i = 16; $i < 64; $i++) {
        $s0 = (rotr($w[$i-15], 7) ^ rotr($w[$i-15], 18) ^ ($w[$i-15] >> 3)) & 0xFFFFFFFF;
        $s1 = (rotr($w[$i-2], 17) ^ rotr($w[$i-2], 19) ^ ($w[$i-2] >> 10)) & 0xFFFFFFFF;
        $w[$i] = ($w[$i-16] + $s0 + $w[$i-7] + $s1) & 0xFFFFFFFF;
    }

    $a = H0[0]; $bb = H0[1]; $c = H0[2]; $d = H0[3];
    $e = H0[4]; $f = H0[5]; $g = H0[6]; $hh = H0[7];
    for ($i = 0; $i < 64; $i++) {
        $S1 = (rotr($e, 6) ^ rotr($e, 11) ^ rotr($e, 25)) & 0xFFFFFFFF;
        $ch = (($e & $f) ^ (($e ^ 0xFFFFFFFF) & $g)) & 0xFFFFFFFF;
        $t1 = ($hh + $S1 + $ch + K[$i] + $w[$i]) & 0xFFFFFFFF;
        $S0 = (rotr($a, 2) ^ rotr($a, 13) ^ rotr($a, 22)) & 0xFFFFFFFF;
        $maj = (($a & $bb) ^ ($a & $c) ^ ($bb & $c)) & 0xFFFFFFFF;
        $t2 = ($S0 + $maj) & 0xFFFFFFFF;
        $hh = $g; $g = $f; $f = $e; $e = ($d + $t1) & 0xFFFFFFFF;
        $d = $c; $c = $bb; $bb = $a; $a = ($t1 + $t2) & 0xFFFFFFFF;
    }

    $h = [
        (H0[0] + $a)  & 0xFFFFFFFF,
        (H0[1] + $bb) & 0xFFFFFFFF,
        (H0[2] + $c)  & 0xFFFFFFFF,
        (H0[3] + $d)  & 0xFFFFFFFF,
        (H0[4] + $e)  & 0xFFFFFFFF,
        (H0[5] + $f)  & 0xFFFFFFFF,
        (H0[6] + $g)  & 0xFFFFFFFF,
        (H0[7] + $hh) & 0xFFFFFFFF,
    ];

    for ($i = 0; $i < 8; $i++) {
        $digest[$i*4]   = ($h[$i] >> 24) & 0xFF;
        $digest[$i*4+1] = ($h[$i] >> 16) & 0xFF;
        $digest[$i*4+2] = ($h[$i] >> 8) & 0xFF;
        $digest[$i*4+3] = $h[$i] & 0xFF;
    }
}

function sha256(int $n): int {
    // seed the 32-byte digest with the pinned LCG
    $d = array_fill(0, 32, 0);
    $s = 42;
    for ($i = 0; $i < 32; $i++) {
        $s = ($s * 1103515245 + 12345) & 0x7fffffff;
        $d[$i] = $s % 256;
    }

    for ($i = 0; $i < $n; $i++) sha256_32($d);

    $h = 0;
    for ($i = 0; $i < 32; $i++) $h = ($h * 31 + $d[$i]) % P;
    return $h;
}

$n = isset($argv[1]) ? (int)$argv[1] : 10000;
echo sha256($n), "\n";
echo "sha256($n)\n";
