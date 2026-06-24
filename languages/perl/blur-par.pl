use strict;
use warnings;
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);

# blur-par: parallel variant of the blur benchmark.
# Invocation: perl blur-par.pl <cores> <n>
#
# Each of the PASSES blur passes is parallelised across `cores` workers.
# Worker w owns output rows [row_start, row_end).  A pixel at (i,j) reads the
# 3x3 neighbourhood from the current source buffer -- including rows row_start-1
# and row_end (neighbours), which are read-only from the source so there is no
# write contention.  The parent reassembles the rows and swaps buffers between
# passes (barrier between passes).  Clamp semantics identical to the serial code.
#
# Inter-process communication: each child encodes its output rows as a
# newline-separated list of integers, writes them to a pipe, and exits.
# The parent reads in band order and overwrites the destination buffer.

use constant {
    P      => 1000000007,
    PASSES => 4,
};

my @K = (1, 2, 1, 2, 4, 2, 1, 2, 1);

sub clampi {
    my ($x, $n) = @_;
    return $x < 0 ? 0 : ($x >= $n ? $n - 1 : $x);
}

# Compute one blur pass for a band of output rows [row_start, row_end) from
# the source buffer (full N*N flat array ref).  Returns a flat list of pixel
# values for those rows.
sub blur_band {
    my ($src, $n, $row_start, $row_end) = @_;
    my @out;
    for my $i ($row_start .. $row_end - 1) {
        for my $j (0 .. $n - 1) {
            my $acc = 0;
            for my $di (-1 .. 1) {
                my $ni = clampi($i + $di, $n);
                for my $dj (-1 .. 1) {
                    my $nj = clampi($j + $dj, $n);
                    $acc += $K[($di + 1) * 3 + ($dj + 1)] * $src->[$ni * $n + $nj];
                }
            }
            push @out, int($acc / 16);
        }
    }
    return @out;
}

my $cores = @ARGV >= 1 ? int($ARGV[0]) : 1;
my $n     = @ARGV >= 2 ? int($ARGV[1]) : 256;

# --- Generate source image (LCG, same as serial) ---
my @buf1;
my @buf2;
my $state = 42;
for my $k (0 .. $n * $n - 1) {
    $state = ($state * 1103515245 + 12345) & 0x7fffffff;
    $buf1[$k] = $state % 256;
}
my $src = \@buf1;
my $dst = \@buf2;

# --- PASSES blur passes ---
my $t0 = clock_gettime(CLOCK_MONOTONIC);
for (1 .. PASSES) {

    if ($cores == 1) {
        # Inline path.
        for my $i (0 .. $n - 1) {
            for my $j (0 .. $n - 1) {
                my $acc = 0;
                for my $di (-1 .. 1) {
                    my $ni = clampi($i + $di, $n);
                    for my $dj (-1 .. 1) {
                        my $nj = clampi($j + $dj, $n);
                        $acc += $K[($di + 1) * 3 + ($dj + 1)] * $src->[$ni * $n + $nj];
                    }
                }
                $dst->[$i * $n + $j] = int($acc / 16);
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
                # Child: compute band, send pixel values line-by-line.
                close $rh;
                my @pixels = blur_band($src, $n, $row_start, $row_end);
                print $wh join("\n", @pixels), "\n";
                close $wh;
                exit 0;
            }

            # Parent
            close $wh;
            $pipes[$w] = [$rh, $row_start, $row_end];
        }

        # Collect from each band in order and write into $dst.
        for my $w (0 .. $cores - 1) {
            my ($rh, $row_start, $row_end) = @{ $pipes[$w] };
            my $rows = $row_end - $row_start;
            my $pixels = $rows * $n;
            my @vals;
            while (defined(my $line = readline($rh))) {
                chomp $line;
                push @vals, int($line);
                last if @vals == $pixels;
            }
            close $rh;
            my $base = $row_start * $n;
            for my $k (0 .. $pixels - 1) {
                $dst->[$base + $k] = $vals[$k];
            }
        }

        # Wait for all children.
        for (1 .. $cores) { wait() }
    }

    ($src, $dst) = ($dst, $src);   # swap buffers (barrier between passes)
}
my $ns = int((clock_gettime(CLOCK_MONOTONIC) - $t0) * 1e9);
print STDERR "COMPUTE_NS $ns\n";

# --- Checksum (serial, same order as serial benchmark) ---
my $h = 0;
for my $k (0 .. $n * $n - 1) {
    $h = ($h * 31 + $src->[$k]) % P;
}

print "$h\n";
print "blur($n)\n";
