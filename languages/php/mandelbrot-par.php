<?php

// mandelbrot-par.php: parallel mandelbrot via pcntl_fork, row-band decomposition.
// Invocation: php mandelbrot-par.php <cores> <n>
// Output: identical to mandelbrot.php at the same n (core-invariant).
//
// Each worker owns rows [row_start, row_end) and sends back a single int64 (the
// in-set pixel count for its band) via a pipe. The parent sums all band counts.

function worker_count(int $y_start, int $y_end, int $n): int {
    $count = 0;
    for ($y = $y_start; $y < $y_end; $y++) {
        $ci = 2.0 * $y / $n - 1.0;
        for ($x = 0; $x < $n; $x++) {
            $cr = 2.0 * $x / $n - 1.5;
            $zr = 0.0;
            $zi = 0.0;
            $tr = 0.0;
            $ti = 0.0;
            $i = 0;
            while ($i < 50 && $tr + $ti <= 4.0) {
                $t  = $zr * $zi;
                $zi = $t + $t + $ci;   // 2*zr*zi + ci, FMA-proof
                $zr = $tr - $ti + $cr;
                $tr = $zr * $zr;
                $ti = $zi * $zi;
                $i++;
            }
            if ($tr + $ti <= 4.0) $count++;
        }
    }
    return $count;
}

$cores = isset($argv[1]) ? (int)$argv[1] : 1;
$n     = isset($argv[2]) ? (int)$argv[2] : 128;

if ($cores <= 1) {
    // Serial fallback: identical to mandelbrot.php
    $t0 = hrtime(true);
    $count = worker_count(0, $n, $n);
    $ns = hrtime(true) - $t0;
    fwrite(STDERR, "COMPUTE_NS $ns\n");
    echo $count, "\n";
    echo "mandelbrot($n)\n";
    exit(0);
}

// Fork $cores workers; each writes an 8-byte packed int64 (LE) to its pipe.
$pipes = [];
$pids  = [];

$t0 = hrtime(true);
for ($w = 0; $w < $cores; $w++) {
    $row_start = intdiv($w * $n, $cores);
    $row_end   = intdiv(($w + 1) * $n, $cores);

    // pipe: [0]=read end (parent), [1]=write end (child)
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
        // Child: close read end, compute, write result, exit.
        fclose($pair[0]);
        $count = worker_count($row_start, $row_end, $n);
        fwrite($pair[1], pack('P', $count));  // 8 bytes, unsigned 64-bit LE
        fclose($pair[1]);
        exit(0);
    }

    // Parent: close write end, keep read end.
    fclose($pair[1]);
    $pipes[$w] = $pair[0];
    $pids[$w]  = $pid;
}

// Parent: collect results in worker order (guaranteed order = core-invariant).
$total = 0;
for ($w = 0; $w < $cores; $w++) {
    $raw = stream_get_contents($pipes[$w]);
    fclose($pipes[$w]);
    $v = unpack('P', $raw);  // 'P' = machine-endian unsigned 64-bit
    $total += $v[1];
}

// Reap children.
for ($w = 0; $w < $cores; $w++) {
    pcntl_waitpid($pids[$w], $status);
}
$ns = hrtime(true) - $t0;
fwrite(STDERR, "COMPUTE_NS $ns\n");

echo $total, "\n";
echo "mandelbrot($n)\n";
