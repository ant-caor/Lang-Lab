<?php

const K = 8;
const P = 1000000007;
const IM = 139968;
const IA = 3877;
const IC = 29573;

function gen(int $L): string {
    $s = str_repeat(' ', $L);
    $seed = 42;
    for ($i = 0; $i < $L; $i++) {
        $seed = ($seed * IA + IC) % IM;
        $s[$i] = $seed < 42000 ? 'A' : ($seed < 70000 ? 'C' : ($seed < 98000 ? 'G' : 'T'));
    }
    return $s;
}

function k_nucleotide(int $L): int {
    $s = gen($L);

    // Count every K-mer, keyed by the K-character substring (string).
    $map = [];
    for ($i = 0; $i + K <= $L; $i++) {
        $kmer = substr($s, $i, K);
        if (isset($map[$kmer])) {
            $map[$kmer]++;
        } else {
            $map[$kmer] = 1;
        }
    }

    // Order-independent checksum: sum of encode(kmer)*count mod P.
    $acc = 0;
    foreach ($map as $kmer => $count) {
        $e = 0;
        for ($j = 0; $j < K; $j++) {
            $c = $kmer[$j];
            $code = $c === 'A' ? 0 : ($c === 'C' ? 1 : ($c === 'G' ? 2 : 3));
            $e = $e * 4 + $code;
        }
        $acc = ($acc + $e * $count) % P;
    }
    return $acc;
}

$L = isset($argv[1]) ? (int)$argv[1] : 100000;
echo k_nucleotide($L), "\n";
echo "k-nucleotide($L)\n";
