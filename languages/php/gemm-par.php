<?php

// gemm-par.php: parallel integer matrix-multiply via pcntl_fork, row-band decomposition.
// Invocation: php gemm-par.php <cores> <n>
// Output: identical to gemm.php at the same n (core-invariant).
//
// Decomposition (scaling-track.md §9):
//   Worker w (0-indexed) computes rows [w*N/cores, (w+1)*N/cores) of C using the
//   pinned i->k->j loop order. Children inherit A and B via COW after fork, write
//   their C rows to the parent through a pipe (packed int64 / net-order uint32 pairs),
//   and the parent assembles full C before running the serial checksum.
//
// COMPUTE_NS is emitted to STDERR covering only the parallel matmul region
// (excludes data-gen and checksum), mirroring blur-par.php.

const GEMM_P = 1000000007;

// Pack an array of PHP ints as 64-bit big-endian values.
// Since pack() has no native int64 format we split each into high/low uint32.
function pack_i64s(array $vals): string {
    $parts = [];
    foreach ($vals as $v) {
        // Values are non-negative accumulations; no sign extension needed.
        $parts[] = ($v >> 32) & 0xFFFFFFFF;
        $parts[] = $v & 0xFFFFFFFF;
    }
    return pack('N*', ...$parts);
}

// Unpack a binary string back to an array of PHP ints (int64).
function unpack_i64s(string $data): array {
    $u32 = array_values(unpack('N*', $data));
    $count = count($u32) >> 1;
    $out = [];
    for ($i = 0; $i < $count; $i++) {
        $out[] = ($u32[$i * 2] << 32) | $u32[$i * 2 + 1];
    }
    return $out;
}

// Compute gemm rows [row_start, row_end) of C, given A and B (both size n*n).
// C is zero-initialized for the band; returns the computed rows as a flat array.
function gemm_band(array $A, array $B, int $n, int $row_start, int $row_end): array {
    $band_size = ($row_end - $row_start) * $n;
    $C_band = array_fill(0, $band_size, 0);

    for ($i = $row_start; $i < $row_end; $i++) {
        $bi = ($i - $row_start) * $n;   // base index into C_band for row i
        for ($k = 0; $k < $n; $k++) {
            $a  = $A[$i * $n + $k];
            $kn = $k * $n;
            for ($j = 0; $j < $n; $j++) {
                $C_band[$bi + $j] += $a * $B[$kn + $j];
            }
        }
    }
    return $C_band;
}

$cores = isset($argv[1]) ? (int)$argv[1] : 1;
$n     = isset($argv[2]) ? (int)$argv[2] : 256;

// --- Data generation (serial, identical to gemm.php) ---
$A = array_fill(0, $n * $n, 0);
$B = array_fill(0, $n * $n, 0);

$s = 42;
for ($i = 0; $i < $n * $n; $i++) {
    $s    = ($s * 1103515245 + 12345) & 0x7fffffff;
    $A[$i] = $s % 128;
}
for ($i = 0; $i < $n * $n; $i++) {
    $s    = ($s * 1103515245 + 12345) & 0x7fffffff;
    $B[$i] = $s % 128;
}

// --- Parallel matmul (COMPUTE_NS wraps only this region) ---
$t0 = hrtime(true);

if ($cores <= 1) {
    // Serial path: single child via fork (or inline for P=1 baseline).
    // Use the same code path as the parallel branch for correctness uniformity.
    $C = array_fill(0, $n * $n, 0);
    for ($i = 0; $i < $n; $i++) {
        for ($k = 0; $k < $n; $k++) {
            $a  = $A[$i * $n + $k];
            $kn = $k * $n;
            $in = $i * $n;
            for ($j = 0; $j < $n; $j++) {
                $C[$in + $j] += $a * $B[$kn + $j];
            }
        }
    }
    $ns = hrtime(true) - $t0;
    fwrite(STDERR, "COMPUTE_NS $ns\n");
} else {
    // Multi-core path: fork one child per band; children return rows via pipes.
    $C = array_fill(0, $n * $n, 0);

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
            $band = gemm_band($A, $B, $n, $row_start, $row_end);
            fwrite($pair[1], pack_i64s($band));
            fclose($pair[1]);
            exit(0);
        }

        // Parent: close write end, remember the read side.
        fclose($pair[1]);
        $pipes[$w] = $pair[0];
        $pids[$w]  = $pid;
    }

    // Collect bands from workers into C in row-major order.
    for ($w = 0; $w < $cores; $w++) {
        $row_start = intdiv($w * $n, $cores);
        $row_end   = intdiv(($w + 1) * $n, $cores);
        $band_rows = $row_end - $row_start;

        $raw  = stream_get_contents($pipes[$w]);
        fclose($pipes[$w]);
        $band = unpack_i64s($raw);

        // Place the band's rows back into the full C array.
        for ($r = 0; $r < $band_rows; $r++) {
            $src_base = $r * $n;
            $dst_base = ($row_start + $r) * $n;
            for ($j = 0; $j < $n; $j++) {
                $C[$dst_base + $j] = $band[$src_base + $j];
            }
        }
    }

    // Reap children.
    for ($w = 0; $w < $cores; $w++) {
        pcntl_waitpid($pids[$w], $status);
    }

    $ns = hrtime(true) - $t0;
    fwrite(STDERR, "COMPUTE_NS $ns\n");
}

// --- Checksum (serial, identical to gemm.php) ---
$h = 0;
for ($i = 0; $i < $n * $n; $i++) {
    $h = ($h * 31 + $C[$i] % GEMM_P) % GEMM_P;
}
$secondary = $C[$n * $n - 1] % GEMM_P;
echo $h, "\n";
echo "gemm($n) = $secondary\n";
