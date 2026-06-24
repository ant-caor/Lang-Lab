<?php

// gbdt-par.php: parallel GBDT inference via pcntl_fork, sample-band decomposition.
// Invocation: php gbdt-par.php <cores> <n>
// Output: identical to gbdt.php at the same n (core-invariant).
//
// Each worker owns samples [s_start, s_end): evaluates all B trees for its samples,
// returns a packed array of (acc per sample). Parent concatenates bands in index order,
// then runs the serial checksum pass identically to gbdt.php.
//
// The tree arrays (feat, thr, leafval) are read-only and inherited via fork COW.

const GBDT_P          = 1000000007;
const GBDT_D          = 8;
const GBDT_B          = 200;
const GBDT_F          = 8;
const GBDT_NODES      = 511;  // 2^(D+1) - 1
const GBDT_LEAF_START = 255;  // 2^D - 1

// Infer samples [s_start, s_end) and return their acc values.
function infer_band(
    array $feat, array $thr, array $leafval, array $sample,
    int $s_start, int $s_end
): array {
    $B          = GBDT_B;
    $D          = GBDT_D;
    $F          = GBDT_F;
    $NODES      = GBDT_NODES;
    $LEAF_START = GBDT_LEAF_START;

    $accs = [];
    for ($i = $s_start; $i < $s_end; $i++) {
        $sbase = $i * $F;
        $acc   = 0;
        for ($b = 0; $b < $B; $b++) {
            $tbase = $b * $NODES;
            $node  = 0;
            for ($d = 0; $d < $D; $d++) {
                if ($sample[$sbase + $feat[$tbase + $node]] <= $thr[$tbase + $node]) {
                    $node = 2 * $node + 1;
                } else {
                    $node = 2 * $node + 2;
                }
            }
            $acc += $leafval[$tbase + $node];
        }
        $accs[] = $acc;
    }
    return $accs;
}

$cores = isset($argv[1]) ? (int)$argv[1] : 1;
$n     = isset($argv[2]) ? (int)$argv[2] : 5000;

// Build tree arrays (same LCG as serial).
$feat    = array_fill(0, GBDT_B * GBDT_NODES, 0);
$thr     = array_fill(0, GBDT_B * GBDT_NODES, 0);
$leafval = array_fill(0, GBDT_B * GBDT_NODES, 0);

$state = 42;
for ($b = 0; $b < GBDT_B; $b++) {
    $base = $b * GBDT_NODES;
    for ($node = 0; $node < GBDT_LEAF_START; $node++) {
        $state          = ($state * 1103515245 + 12345) & 0x7fffffff;
        $feat[$base + $node] = $state % GBDT_F;
        $state          = ($state * 1103515245 + 12345) & 0x7fffffff;
        $thr[$base + $node]  = $state % 256;
    }
    for ($node = GBDT_LEAF_START; $node < GBDT_NODES; $node++) {
        $state              = ($state * 1103515245 + 12345) & 0x7fffffff;
        $leafval[$base + $node] = $state % 10;
    }
}

$sample = array_fill(0, $n * GBDT_F, 0);
for ($i = 0; $i < $n * GBDT_F; $i++) {
    $state     = ($state * 1103515245 + 12345) & 0x7fffffff;
    $sample[$i] = $state % 256;
}

if ($cores <= 1) {
    // Serial path: identical to gbdt.php
    $t0    = hrtime(true);
    $accs1 = [];
    for ($i = 0; $i < $n; $i++) {
        $sbase = $i * GBDT_F;
        $acc   = 0;
        for ($b = 0; $b < GBDT_B; $b++) {
            $tbase = $b * GBDT_NODES;
            $node  = 0;
            for ($d = 0; $d < GBDT_D; $d++) {
                if ($sample[$sbase + $feat[$tbase + $node]] <= $thr[$tbase + $node]) {
                    $node = 2 * $node + 1;
                } else {
                    $node = 2 * $node + 2;
                }
            }
            $acc += $leafval[$tbase + $node];
        }
        $accs1[] = $acc;
    }
    $ns = hrtime(true) - $t0;
    fwrite(STDERR, "COMPUTE_NS $ns\n");
    $h     = 0;
    $total = 0;
    foreach ($accs1 as $acc) {
        $h     = ($h * 31 + $acc + 1) % GBDT_P;
        $total = ($total + $acc)       % GBDT_P;
    }
    echo $h, "\n";
    echo "gbdt($n) = $total\n";
    exit(0);
}

// Fork workers; each sends back a packed int64 array of acc values for its samples.
$pipes = [];
$pids  = [];

$t0 = hrtime(true);
for ($w = 0; $w < $cores; $w++) {
    $s_start = intdiv($w * $n, $cores);
    $s_end   = intdiv(($w + 1) * $n, $cores);

    $pair = stream_socket_pair(STREAM_PF_UNIX, STREAM_SOCK_STREAM, STREAM_IPPROTO_IP);
    if ($pair === false) {
        fwrite(STDERR, "stream_socket_pair failed\n");
        exit(1);
    }

    $pid = pcntl_fork();
    if ($pid < 0) {
        fwrite(STDERR, "pcntl_fork failed\n");
        exit(1);
    }

    if ($pid === 0) {
        fclose($pair[0]);
        $accs = infer_band($feat, $thr, $leafval, $sample, $s_start, $s_end);
        // Pack as unsigned 64-bit LE; acc is a sum of at most B*9 = 1800, fits in uint64.
        $blob = '';
        foreach ($accs as $v) {
            $blob .= pack('P', $v);
        }
        fwrite($pair[1], $blob);
        fclose($pair[1]);
        exit(0);
    }

    fclose($pair[1]);
    $pipes[$w] = $pair[0];
    $pids[$w]  = $pid;
}

// Collect and concatenate acc arrays in worker (index) order.
$all_accs = array_fill(0, $n, 0);

for ($w = 0; $w < $cores; $w++) {
    $s_start = intdiv($w * $n, $cores);
    $s_end   = intdiv(($w + 1) * $n, $cores);
    $count   = $s_end - $s_start;

    $raw = stream_get_contents($pipes[$w]);
    fclose($pipes[$w]);

    for ($i = 0; $i < $count; $i++) {
        $v = unpack('P', substr($raw, $i * 8, 8));
        $all_accs[$s_start + $i] = $v[1];
    }
}

for ($w = 0; $w < $cores; $w++) {
    pcntl_waitpid($pids[$w], $status);
}
$ns = hrtime(true) - $t0;
fwrite(STDERR, "COMPUTE_NS $ns\n");

// Serial checksum (identical order to gbdt.php).
$h     = 0;
$total = 0;
for ($i = 0; $i < $n; $i++) {
    $acc   = $all_accs[$i];
    $h     = ($h * 31 + $acc + 1) % GBDT_P;
    $total = ($total + $acc)       % GBDT_P;
}
echo $h, "\n";
echo "gbdt($n) = $total\n";
