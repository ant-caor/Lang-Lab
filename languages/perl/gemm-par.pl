use strict;
use warnings;
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);

# gemm-par: parallel variant of the gemm benchmark (scaling track).
# Invocation: perl gemm-par.pl <cores> <n>
#
# Row-band decomposition (scaling-track.md §9):
#   Worker w (0-indexed) computes rows [w*N/cores, (w+1)*N/cores).
#   Loop order i->k->j is pinned (same as serial).
#   Workers write disjoint rows of C; A and B are read-only.
#   Checksum runs single-threaded after all workers join, in the same
#   row-major order as the serial benchmark -> core-invariant output.
#
# Primitive: fork + pipe (mirrors blur-par.pl).
#   Each child encodes its C rows as newline-separated integers and writes
#   them to a pipe; the parent reassembles in band order before checksumming.

use constant P => 1000000007;

my $cores = @ARGV >= 1 ? int($ARGV[0]) : 1;
my $n     = @ARGV >= 2 ? int($ARGV[1]) : 256;

# --- Generate A and B (same LCG as serial gemm, same order) ---
my @A;
my @B;
my $state = 42;
for my $i (0 .. $n * $n - 1) {
    $state = ($state * 1103515245 + 12345) & 0x7fffffff;
    $A[$i] = $state % 128;
}
for my $i (0 .. $n * $n - 1) {
    $state = ($state * 1103515245 + 12345) & 0x7fffffff;
    $B[$i] = $state % 128;
}

# C is zero-initialised; each worker fills its rows.
my @C = (0) x ($n * $n);

# --- Parallel matmul (COMPUTE_NS timer starts here) ---
my $t0 = clock_gettime(CLOCK_MONOTONIC);

if ($cores == 1) {
    # Single-threaded path: inline loop identical to serial gemm.
    for my $i (0 .. $n - 1) {
        for my $k (0 .. $n - 1) {
            my $a    = $A[$i * $n + $k];
            my $kn   = $k * $n;
            my $base = $i * $n;
            for my $j (0 .. $n - 1) {
                $C[$base + $j] += $a * $B[$kn + $j];
            }
        }
    }
} else {
    # Parallel path: fork one worker per band.
    my @pipes;

    for my $w (0 .. $cores - 1) {
        my $row_start = int($w * $n / $cores);
        my $row_end   = int(($w + 1) * $n / $cores);

        pipe(my $rh, my $wh) or die "pipe: $!";

        my $pid = fork();
        die "fork: $!" unless defined $pid;

        if ($pid == 0) {
            # Child: compute assigned rows and send C values line-by-line.
            close $rh;
            for my $i ($row_start .. $row_end - 1) {
                my $base = $i * $n;
                # Accumulate into a local row to avoid touching parent's @C.
                my @row = (0) x $n;
                for my $k (0 .. $n - 1) {
                    my $a  = $A[$i * $n + $k];
                    my $kn = $k * $n;
                    for my $j (0 .. $n - 1) {
                        $row[$j] += $a * $B[$kn + $j];
                    }
                }
                print $wh join("\n", @row), "\n";
            }
            close $wh;
            exit 0;
        }

        # Parent: record pipe read end + band boundaries.
        close $wh;
        $pipes[$w] = [$rh, $row_start, $row_end];
    }

    # Collect from each band in order and write into @C.
    for my $w (0 .. $cores - 1) {
        my ($rh, $row_start, $row_end) = @{ $pipes[$w] };
        my $rows   = $row_end - $row_start;
        my $ncells = $rows * $n;
        my @vals;
        while (defined(my $line = readline($rh))) {
            chomp $line;
            push @vals, int($line);
            last if @vals == $ncells;
        }
        close $rh;
        my $base = $row_start * $n;
        for my $k (0 .. $ncells - 1) {
            $C[$base + $k] = $vals[$k];
        }
    }

    # Wait for all children.
    for (1 .. $cores) { wait() }
}

my $ns = int((clock_gettime(CLOCK_MONOTONIC) - $t0) * 1e9);
print STDERR "COMPUTE_NS $ns\n";

# --- Checksum (serial, same order as serial gemm) ---
my $h = 0;
for my $i (0 .. $n * $n - 1) {
    $h = ($h * 31 + $C[$i] % P) % P;
}
my $secondary = $C[$n * $n - 1] % P;

print "$h\n";
print "gemm($n) = $secondary\n";
