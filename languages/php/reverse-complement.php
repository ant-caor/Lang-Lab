<?php

// reverse-complement: generate a DNA sequence, reverse it in place while complementing
// each base (A<->T, C<->G), then reduce it to a polynomial string hash. The reverse uses a
// hand-written two-pointer loop (NOT a stdlib bulk reverse) and the hash a per-character
// loop (NOT a builtin), so this measures the language's own per-character processing -
// consistent with the suite's no-stdlib-shortcut rule. Everything is integer-deterministic.
// PHP strings are mutable by index ($s[$i] = ...), so the string is the mutable buffer.

const P = 1000000007;
const IM = 139968;
const IA = 3877;
const IC = 29573;

function comp(int $c): int {            // A<->T, C<->G; only A/C/G/T occur
    return $c === ord('A') ? ord('T')
         : ($c === ord('C') ? ord('G')
         : ($c === ord('G') ? ord('C') : ord('A')));
}

function reverse_complement(int $L): int {
    $s = str_repeat("\0", $L);          // mutable byte buffer ($s[$i] is assignable)
    $seed = 42;
    for ($i = 0; $i < $L; $i++) {
        $seed = ($seed * IA + IC) % IM;
        $s[$i] = $seed < 42000 ? 'A' : ($seed < 70000 ? 'C' : ($seed < 98000 ? 'G' : 'T'));
    }
    $i = 0; $j = $L - 1;
    while ($i < $j) {                    // two-pointer reverse-and-complement, in place
        $a = comp(ord($s[$i]));
        $s[$i] = chr(comp(ord($s[$j])));
        $s[$j] = chr($a);
        $i++; $j--;
    }
    if ($i === $j) $s[$i] = chr(comp(ord($s[$i])));
    $h = 0;
    for ($k = 0; $k < $L; $k++) {        // polynomial hash over the ASCII byte values
        $h = ($h * 31 + ord($s[$k])) % P;
    }
    return $h;
}

$L = isset($argv[1]) ? (int)$argv[1] : 100000;
echo reverse_complement($L), "\n";
echo "reverse-complement($L)\n";
