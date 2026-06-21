<?php

// viterbi: integer HMM sequence decoding — the classical max-plus trellis.
// S=8 states, ALPHA=4 symbols, T=size parameter. LCG (glibc-style, seed=42)
// draws trans[S*S], emit[S*ALPHA], obs[T] in that order. Forward pass is a
// loop-carried max-reduction (STRICT > tie-break: lowest i wins), followed by
// a pointer-chain backtrace. Checksum = poly-hash of (path[t]+1).
// Secondary = optimal total path score mod P. No HMM library; pure integer.

const S     = 8;
const ALPHA = 4;
const P     = 1000000007;

function viterbi(int $t): array {
    // Draw order: trans[S*S], emit[S*ALPHA], obs[T]
    $trans = array_fill(0, S * S, 0);
    $emit  = array_fill(0, S * ALPHA, 0);
    $obs   = array_fill(0, $t, 0);
    $state = 42;
    for ($x = 0; $x < S * S; $x++) {
        $state = ($state * 1103515245 + 12345) & 0x7fffffff;
        $trans[$x] = $state % 100 + 1;
    }
    for ($x = 0; $x < S * ALPHA; $x++) {
        $state = ($state * 1103515245 + 12345) & 0x7fffffff;
        $emit[$x] = $state % 100 + 1;
    }
    for ($i = 0; $i < $t; $i++) {
        $state = ($state * 1103515245 + 12345) & 0x7fffffff;
        $obs[$i] = $state % ALPHA;
    }

    // Initialise t=0
    $vit_prev = array_fill(0, S, 0);
    for ($j = 0; $j < S; $j++) {
        $vit_prev[$j] = $emit[$j * ALPHA + $obs[0]];
    }

    $back = array_fill(0, $t * S, 0);

    // Forward trellis t=1..T-1
    $vit_next = array_fill(0, S, 0);
    for ($ti = 1; $ti < $t; $ti++) {
        for ($j = 0; $j < S; $j++) {
            $best = -1; $bi = 0;
            $e = $emit[$j * ALPHA + $obs[$ti]];
            for ($i = 0; $i < S; $i++) {
                $sc = $vit_prev[$i] + $trans[$i * S + $j] + $e;
                if ($sc > $best) {   // STRICT > -> lowest i wins
                    $best = $sc; $bi = $i;
                }
            }
            $vit_next[$j] = $best;
            $back[$ti * S + $j] = $bi;
        }
        $vit_prev = $vit_next;
    }

    // Final state: STRICT > -> lowest j wins
    $bf = 0;
    for ($j = 1; $j < S; $j++) {
        if ($vit_prev[$j] > $vit_prev[$bf]) { $bf = $j; }
    }

    // Backtrace
    $path = array_fill(0, $t, 0);
    $path[$t - 1] = $bf;
    for ($ti = $t - 2; $ti >= 0; $ti--) {
        $path[$ti] = $back[($ti + 1) * S + $path[$ti + 1]];
    }

    // Checksum
    $h = 0;
    for ($ti = 0; $ti < $t; $ti++) {
        $h = ($h * 31 + $path[$ti] + 1) % P;
    }

    $secondary = $vit_prev[$bf] % P;
    return [$h, $secondary];
}

$t = isset($argv[1]) ? (int)$argv[1] : 20000;
[$h, $sec] = viterbi($t);
echo $h, "\n";
echo "viterbi($t) = $sec\n";
