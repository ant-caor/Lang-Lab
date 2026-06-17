<?php

// sort-search: generate N integers, sort them with a hand-written median-of-three
// quicksort (Hoare partition), then run N binary searches and fold the found indices
// into a checksum. The two classic algorithms - quicksort and binary search - written
// out explicitly (no stdlib sort/bsearch). All integer; PHP ints are 64-bit here.

const P = 1000000007;

function lcg_next(int $s): int {
    return ($s * 1103515245 + 12345) & 0x7fffffff;
}

// median-of-three + Hoare partition, recurse both sides; depth stays ~log N.
function qsort_h(array &$a, int $lo, int $hi): void {
    if ($lo >= $hi) return;
    $mid = $lo + intdiv($hi - $lo, 2);
    if ($a[$mid] < $a[$lo]) { $t = $a[$lo]; $a[$lo] = $a[$mid]; $a[$mid] = $t; }
    if ($a[$hi]  < $a[$lo]) { $t = $a[$lo]; $a[$lo] = $a[$hi];  $a[$hi]  = $t; }
    if ($a[$hi]  < $a[$mid]) { $t = $a[$mid]; $a[$mid] = $a[$hi]; $a[$hi] = $t; }
    $pivot = $a[$mid];
    $i = $lo - 1;
    $j = $hi + 1;
    for (;;) {
        do { $i++; } while ($a[$i] < $pivot);
        do { $j--; } while ($a[$j] > $pivot);
        if ($i >= $j) break;
        $t = $a[$i]; $a[$i] = $a[$j]; $a[$j] = $t;
    }
    qsort_h($a, $lo, $j);
    qsort_h($a, $j + 1, $hi);
}

function bsearch_i(array &$a, int $n, int $key): int {
    $lo = 0;
    $hi = $n - 1;
    while ($lo <= $hi) {
        $mid = $lo + intdiv($hi - $lo, 2);
        if ($a[$mid] < $key) $lo = $mid + 1;
        elseif ($a[$mid] > $key) $hi = $mid - 1;
        else return $mid;
    }
    return -1;
}

function sort_search(int $n): int {
    $a = [];
    $state = 42;
    for ($i = 0; $i < $n; $i++) {
        $state = lcg_next($state);
        $a[$i] = $state;
    }
    qsort_h($a, 0, $n - 1);
    $h = 0;
    for ($q = 0; $q < $n; $q++) {
        $state = lcg_next($state);
        $key = $a[$state % $n];          // a value present in the sorted array -> a hit
        $idx = bsearch_i($a, $n, $key);
        $h = ($h * 31 + ($idx + 1)) % P;
    }
    return $h;
}

$n = isset($argv[1]) ? (int)$argv[1] : 100000;
echo sort_search($n), "\n";
echo "sort-search($n)\n";
