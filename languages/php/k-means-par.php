<?php

// k-means-par.php: parallel Lloyd's k-means via pcntl_fork, point-band decomposition.
// Invocation: php k-means-par.php <cores> <n>
// Output: identical to k-means.php at the same n (core-invariant).
//
// Parallel structure per iteration:
//   1. Parent broadcasts current centroids (inherited via fork COW).
//   2. Each worker owns points [pt_start, pt_end): computes nearest centroid for each,
//      accumulates per-cluster sums and counts for its band.
//   3. Worker returns: assign[] for its band (packed int32) + sums (packed int64) + cnts.
//   4. Parent merges partial sums/counts, performs serial floor-mean centroid update.
//   5. After all ITERS, final assignment pass (same parallel pattern).
//   6. Serial checksum pass.
//
// Tie-break: lowest-index centroid (strict <) -- identical to serial, per-point within band.

const KM_P     = 1000000007;
const KM_K     = 16;
const KM_D     = 4;
const KM_ITERS = 10;
const KM_RANGE = 256;

// Assign points [pt_start, pt_end) to nearest centroid.
// Returns [assign_band[], ssum[K*D], cnt[K]].
function assign_band(array $pt, array $cen, int $pt_start, int $pt_end): array {
    $K = KM_K;
    $D = KM_D;
    $assign = [];
    $ssum   = array_fill(0, $K * $D, 0);
    $cnt    = array_fill(0, $K, 0);

    for ($i = $pt_start; $i < $pt_end; $i++) {
        $best = 0;
        $bd   = -1;
        for ($k = 0; $k < $K; $k++) {
            $dist = 0;
            for ($d = 0; $d < $D; $d++) {
                $df   = $pt[$i * $D + $d] - $cen[$k * $D + $d];
                $dist += $df * $df;
            }
            if ($bd < 0 || $dist < $bd) {
                $bd   = $dist;
                $best = $k;
            }
        }
        $assign[] = $best;
        $cnt[$best]++;
        for ($d = 0; $d < $D; $d++) {
            $ssum[$best * $D + $d] += $pt[$i * $D + $d];
        }
    }
    return [$assign, $ssum, $cnt];
}

// Serialize worker result: assign(N int32) | ssum(K*D int64 LE) | cnt(K int64 LE)
function serialize_result(array $assign, array $ssum, array $cnt): string {
    $K = KM_K;
    $D = KM_D;
    $data  = pack('N*', ...$assign);           // unsigned 32-bit, each fits (0..K-1)
    foreach ($ssum as $v) {
        $data .= pack('P', $v);                // unsigned 64-bit LE
    }
    foreach ($cnt as $v) {
        $data .= pack('P', $v);
    }
    return $data;
}

function deserialize_result(string $data, int $pt_count): array {
    $K      = KM_K;
    $D      = KM_D;
    $offset = 0;

    // assign: pt_count * 4 bytes
    $assign_bytes = $pt_count * 4;
    $assign = array_values(unpack('N*', substr($data, $offset, $assign_bytes)));
    $offset += $assign_bytes;

    // ssum: K*D * 8 bytes
    $ssum = [];
    for ($i = 0; $i < $K * $D; $i++) {
        $v      = unpack('P', substr($data, $offset, 8));
        $ssum[] = $v[1];
        $offset += 8;
    }

    // cnt: K * 8 bytes
    $cnt = [];
    for ($i = 0; $i < $K; $i++) {
        $v     = unpack('P', substr($data, $offset, 8));
        $cnt[] = $v[1];
        $offset += 8;
    }

    return [$assign, $ssum, $cnt];
}

$cores = isset($argv[1]) ? (int)$argv[1] : 1;
$n     = isset($argv[2]) ? (int)$argv[2] : 8000;

// Generate points (same as serial).
$pt = array_fill(0, $n * KM_D, 0);
$s  = 42;
for ($i = 0; $i < $n * KM_D; $i++) {
    $s      = ($s * 1103515245 + 12345) & 0x7fffffff;
    $pt[$i] = $s % KM_RANGE;
}

// Initial centroids = first K points.
$cen = array_fill(0, KM_K * KM_D, 0);
for ($i = 0; $i < KM_K * KM_D; $i++) $cen[$i] = $pt[$i];

$assign = array_fill(0, $n, 0);

if ($cores <= 1) {
    // Serial path: identical to k-means.php
    $t0 = hrtime(true);
    for ($iter = 0; $iter < KM_ITERS; $iter++) {
        for ($i = 0; $i < $n; $i++) {
            $best = 0; $bd = -1;
            for ($k = 0; $k < KM_K; $k++) {
                $dist = 0;
                for ($d = 0; $d < KM_D; $d++) {
                    $df = $pt[$i * KM_D + $d] - $cen[$k * KM_D + $d];
                    $dist += $df * $df;
                }
                if ($bd < 0 || $dist < $bd) { $bd = $dist; $best = $k; }
            }
            $assign[$i] = $best;
        }
        $ssum = array_fill(0, KM_K * KM_D, 0);
        $cnt  = array_fill(0, KM_K, 0);
        for ($i = 0; $i < $n; $i++) {
            $k = $assign[$i]; $cnt[$k]++;
            for ($d = 0; $d < KM_D; $d++) $ssum[$k * KM_D + $d] += $pt[$i * KM_D + $d];
        }
        for ($k = 0; $k < KM_K; $k++) {
            if ($cnt[$k] > 0) {
                for ($d = 0; $d < KM_D; $d++) {
                    $cen[$k * KM_D + $d] = intdiv($ssum[$k * KM_D + $d], $cnt[$k]);
                }
            }
        }
    }
    // Final assignment.
    for ($i = 0; $i < $n; $i++) {
        $best = 0; $bd = -1;
        for ($k = 0; $k < KM_K; $k++) {
            $dist = 0;
            for ($d = 0; $d < KM_D; $d++) {
                $df = $pt[$i * KM_D + $d] - $cen[$k * KM_D + $d];
                $dist += $df * $df;
            }
            if ($bd < 0 || $dist < $bd) { $bd = $dist; $best = $k; }
        }
        $assign[$i] = $best;
    }
    $ns = hrtime(true) - $t0;
    fwrite(STDERR, "COMPUTE_NS $ns\n");
    $h = 0;
    for ($i = 0; $i < KM_K * KM_D; $i++) $h = ($h * 31 + $cen[$i]) % KM_P;
    for ($i = 0; $i < $n; $i++) $h = ($h * 31 + $assign[$i]) % KM_P;
    echo $h, "\n";
    echo "k-means($n)\n";
    exit(0);
}

// Parallel iterations.
// run_parallel_assign() forks $cores workers, collects assign+ssum+cnt, merges.
// $cen is passed as a global (inherited by child via COW).

function run_parallel_assign(
    array $pt, array $cen, int $n, int $cores, bool $collect_ssum
): array {
    $pipes = [];
    $pids  = [];

    for ($w = 0; $w < $cores; $w++) {
        $pt_start = intdiv($w * $n, $cores);
        $pt_end   = intdiv(($w + 1) * $n, $cores);

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
            [$band_assign, $ssum, $cnt] = assign_band($pt, $cen, $pt_start, $pt_end);
            fwrite($pair[1], serialize_result($band_assign, $ssum, $cnt));
            fclose($pair[1]);
            exit(0);
        }

        fclose($pair[1]);
        $pipes[$w] = $pair[0];
        $pids[$w]  = $pid;
    }

    // Merge.
    $assign      = array_fill(0, $n, 0);
    $merged_ssum = array_fill(0, KM_K * KM_D, 0);
    $merged_cnt  = array_fill(0, KM_K, 0);

    for ($w = 0; $w < $cores; $w++) {
        $pt_start  = intdiv($w * $n, $cores);
        $pt_end    = intdiv(($w + 1) * $n, $cores);
        $pt_count  = $pt_end - $pt_start;

        $raw = stream_get_contents($pipes[$w]);
        fclose($pipes[$w]);

        [$band_assign, $ssum, $cnt] = deserialize_result($raw, $pt_count);

        for ($i = 0; $i < $pt_count; $i++) {
            $assign[$pt_start + $i] = $band_assign[$i];
        }
        if ($collect_ssum) {
            for ($i = 0; $i < KM_K * KM_D; $i++) $merged_ssum[$i] += $ssum[$i];
            for ($i = 0; $i < KM_K; $i++)       $merged_cnt[$i]  += $cnt[$i];
        }
    }

    for ($w = 0; $w < $cores; $w++) {
        pcntl_waitpid($pids[$w], $status);
    }

    return [$assign, $merged_ssum, $merged_cnt];
}

// Main loop.
$t0 = hrtime(true);
for ($iter = 0; $iter < KM_ITERS; $iter++) {
    [$assign, $merged_ssum, $merged_cnt] = run_parallel_assign($pt, $cen, $n, $cores, true);

    // Serial centroid update (floor-mean, empty-cluster unchanged).
    for ($k = 0; $k < KM_K; $k++) {
        if ($merged_cnt[$k] > 0) {
            for ($d = 0; $d < KM_D; $d++) {
                $cen[$k * KM_D + $d] = intdiv($merged_ssum[$k * KM_D + $d], $merged_cnt[$k]);
            }
        }
    }
}

// Final assignment (parallel, ssum not needed).
[$assign] = run_parallel_assign($pt, $cen, $n, $cores, false);
$ns = hrtime(true) - $t0;
fwrite(STDERR, "COMPUTE_NS $ns\n");

// Serial checksum.
$h = 0;
for ($i = 0; $i < KM_K * KM_D; $i++) $h = ($h * 31 + $cen[$i]) % KM_P;
for ($i = 0; $i < $n; $i++) $h = ($h * 31 + $assign[$i]) % KM_P;
echo $h, "\n";
echo "k-means($n)\n";
