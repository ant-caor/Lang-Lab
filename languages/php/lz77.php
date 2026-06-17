<?php

// lz77: a hand-written LZ77 compressor - the data-compression / sliding-window axis.
// Generate an LCG byte stream over a small alphabet (so matches are common), then at each
// position brute-force scan the previous WINDOW bytes for the longest match (closest wins
// ties), emit a (distance, length) back-reference or a literal, and advance greedily. The
// whole token stream folds into a polynomial hash. No compression library, no hash-chain /
// suffix-tree acceleration - the same O(N*WINDOW) window scan as every other language.
// All integer; PHP ints are 64-bit, so the poly-hash h*31 (~3.1e10) stays exact.

const P = 1000000007;
const WINDOW = 512;
const MIN_MATCH = 3;
const MAX_MATCH = 255;
const ALPHA = 6;

function lz77(int $n): int {
    $in = [];
    $s = 42;
    for ($i = 0; $i < $n; $i++) {
        $s = ($s * 1103515245 + 12345) & 0x7fffffff;
        $in[$i] = $s % ALPHA;
    }
    $pos = 0;
    $h = 0;
    while ($pos < $n) {
        $bestLen = 0;
        $bestDist = 0;
        $start = $pos - WINDOW;
        if ($start < 0) $start = 0;
        for ($cand = $pos - 1; $cand >= $start; $cand--) {   // closest distance first
            $len = 0;
            while ($pos + $len < $n && $len < MAX_MATCH && $in[$cand + $len] === $in[$pos + $len]) {
                $len++;
            }
            if ($len > $bestLen) {                            // strict > : closest wins ties
                $bestLen = $len;
                $bestDist = $pos - $cand;
            }
        }
        if ($bestLen >= MIN_MATCH) {
            $h = ($h * 31 + 1) % P;
            $h = ($h * 31 + $bestDist) % P;
            $h = ($h * 31 + $bestLen) % P;
            $pos += $bestLen;
        } else {
            $h = ($h * 31 + 0) % P;
            $h = ($h * 31 + $in[$pos]) % P;
            $pos += 1;
        }
    }
    return $h;
}

$n = isset($argv[1]) ? (int)$argv[1] : 24000;
echo lz77($n), "\n";
echo "lz77($n)\n";
