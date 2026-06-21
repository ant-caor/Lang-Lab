<?php

// gemm: quantized integer matrix-multiply - the dominant ML inference kernel.
// Square matmul of side N (i.e. N x N matrices). Loop order i,k,j (pinned)
// so B is accessed row-sequentially. LCG fills A then B with values 0..127.
// Accumulator is 64-bit; checksum = poly-hash of C row-major mod 1e9+7.
// No BLAS / no library matmul - the explicit triple loop.

const P = 1000000007;

function gemm(int $n): array {
    $A = array_fill(0, $n * $n, 0);
    $B = array_fill(0, $n * $n, 0);

    $s = 42;
    for ($i = 0; $i < $n * $n; $i++) {
        $s = ($s * 1103515245 + 12345) & 0x7fffffff;
        $A[$i] = $s % 128;
    }
    for ($i = 0; $i < $n * $n; $i++) {
        $s = ($s * 1103515245 + 12345) & 0x7fffffff;
        $B[$i] = $s % 128;
    }

    $C = array_fill(0, $n * $n, 0);

    // Pinned loop order i, k, j - B read row-sequentially.
    for ($i = 0; $i < $n; $i++) {
        for ($k = 0; $k < $n; $k++) {
            $a    = $A[$i * $n + $k];
            $kn   = $k * $n;
            $base = $i * $n;
            for ($j = 0; $j < $n; $j++) {
                $C[$base + $j] += $a * $B[$kn + $j];
            }
        }
    }

    $h = 0;
    for ($i = 0; $i < $n * $n; $i++) {
        $h = ($h * 31 + $C[$i] % P) % P;
    }
    $secondary = $C[$n * $n - 1] % P;
    return [$h, $secondary];
}

$n = isset($argv[1]) ? (int)$argv[1] : 256;
[$h, $sec] = gemm($n);
echo $h, "\n";
echo "gemm($n) = $sec\n";
