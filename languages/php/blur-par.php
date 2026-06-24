<?php

// blur-par.php: parallel Gaussian blur via pcntl_fork, row-band decomposition per pass.
// Invocation: php blur-par.php <cores> <n>
// Output: identical to blur.php at the same n (core-invariant).
//
// Per-pass parallel strategy:
//   - Parent holds the full src/dst arrays in shared memory (via shmop) so workers
//     can read the entire src (including rows outside their band) for neighbour access.
//   - Each worker owns output rows [row_start, row_end) and writes its band back to
//     the parent via a pipe (packed int32 array).
//   - After all workers return, the parent assembles dst from the bands and swaps
//     src<->dst for the next pass.
//
// Note: shmop requires --enable-shmop which is not always compiled in. As a safe
// fallback the implementation serializes the full src via the pipe's stdin side
// in the child (read before fork sends src as a pipe message). Actually, the cleanest
// approach for PHP processes is to pass src via a pipe from parent to child before
// forking -- but since forks inherit memory, the child already has a copy of src.
// PHP forks with copy-on-write, so the child reads its inherited copy of $src directly.
// This is the correct pattern: fork AFTER building src, child reads its COW copy.

const BLUR_P     = 1000000007;
const BLUR_PASSES = 4;

function lcg_blur(int $s): int {
    return ($s * 1103515245 + 12345) & 0x7fffffff;
}

function clampi_blur(int $x, int $n): int {
    return $x < 0 ? 0 : ($x >= $n ? $n - 1 : $x);
}

// Compute one blur pass over rows [row_start, row_end) of src (size n*n).
// Returns the output pixels for those rows (packed as an array of ints).
function blur_band(array $src, int $n, int $row_start, int $row_end): array {
    static $K = [1, 2, 1, 2, 4, 2, 1, 2, 1];
    $out = [];
    for ($i = $row_start; $i < $row_end; $i++) {
        for ($j = 0; $j < $n; $j++) {
            $acc = 0;
            for ($di = -1; $di <= 1; $di++) {
                $ni = clampi_blur($i + $di, $n);
                for ($dj = -1; $dj <= 1; $dj++) {
                    $nj = clampi_blur($j + $dj, $n);
                    $acc += $K[($di + 1) * 3 + ($dj + 1)] * $src[$ni * $n + $nj];
                }
            }
            $out[] = intdiv($acc, 16);
        }
    }
    return $out;
}

// Pack an int array as a sequence of 4-byte signed ints (big-endian).
function pack_ints(array $vals): string {
    return pack('N*', ...$vals);
}

// Unpack a binary string back to an int array.
function unpack_ints(string $data): array {
    return array_values(unpack('N*', $data));
}

$cores = isset($argv[1]) ? (int)$argv[1] : 1;
$n     = isset($argv[2]) ? (int)$argv[2] : 256;

// Build initial image (same as serial).
$src = [];
$s   = 42;
for ($k = 0; $k < $n * $n; $k++) {
    $s      = lcg_blur($s);
    $src[$k] = $s % 256;
}

if ($cores <= 1) {
    // Serial path: identical to blur.php
    $dst = [];
    $K = [1, 2, 1, 2, 4, 2, 1, 2, 1];
    $t0 = hrtime(true);
    for ($pass = 0; $pass < BLUR_PASSES; $pass++) {
        for ($i = 0; $i < $n; $i++) {
            for ($j = 0; $j < $n; $j++) {
                $acc = 0;
                for ($di = -1; $di <= 1; $di++) {
                    $ni = clampi_blur($i + $di, $n);
                    for ($dj = -1; $dj <= 1; $dj++) {
                        $nj = clampi_blur($j + $dj, $n);
                        $acc += $K[($di + 1) * 3 + ($dj + 1)] * $src[$ni * $n + $nj];
                    }
                }
                $dst[$i * $n + $j] = intdiv($acc, 16);
            }
        }
        $t = $src; $src = $dst; $dst = $t;
    }
    $ns = hrtime(true) - $t0;
    fwrite(STDERR, "COMPUTE_NS $ns\n");
    $h = 0;
    for ($k = 0; $k < $n * $n; $k++) {
        $h = ($h * 31 + $src[$k]) % BLUR_P;
    }
    echo $h, "\n";
    echo "blur($n)\n";
    exit(0);
}

// Multi-pass parallel blur.
// Each pass: fork $cores workers (each inherits current $src via COW), collect
// their output bands into $dst, swap $src<->$dst.

$dst = array_fill(0, $n * $n, 0);

$t0 = hrtime(true);
for ($pass = 0; $pass < BLUR_PASSES; $pass++) {
    $pipes = [];
    $pids  = [];

    for ($w = 0; $w < $cores; $w++) {
        $row_start = intdiv($w * $n, $cores);
        $row_end   = intdiv(($w + 1) * $n, $cores);

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
            // Child: close read end, compute band, write packed ints, exit.
            fclose($pair[0]);
            $band = blur_band($src, $n, $row_start, $row_end);
            fwrite($pair[1], pack_ints($band));
            fclose($pair[1]);
            exit(0);
        }

        fclose($pair[1]);
        $pipes[$w] = $pair[0];
        $pids[$w]  = $pid;
    }

    // Collect bands from workers in order.
    for ($w = 0; $w < $cores; $w++) {
        $row_start = intdiv($w * $n, $cores);
        $row_end   = intdiv(($w + 1) * $n, $cores);
        $band_rows = $row_end - $row_start;

        $raw  = stream_get_contents($pipes[$w]);
        fclose($pipes[$w]);
        $band = unpack_ints($raw);

        for ($r = 0; $r < $band_rows; $r++) {
            for ($j = 0; $j < $n; $j++) {
                $dst[($row_start + $r) * $n + $j] = $band[$r * $n + $j];
            }
        }
    }

    // Reap children.
    for ($w = 0; $w < $cores; $w++) {
        pcntl_waitpid($pids[$w], $status);
    }

    // Swap src <-> dst (same as serial double-buffer).
    $t = $src; $src = $dst; $dst = $t;
}
$ns = hrtime(true) - $t0;
fwrite(STDERR, "COMPUTE_NS $ns\n");

// Final checksum (serial, identical to blur.php).
$h = 0;
for ($k = 0; $k < $n * $n; $k++) {
    $h = ($h * 31 + $src[$k]) % BLUR_P;
}
echo $h, "\n";
echo "blur($n)\n";
