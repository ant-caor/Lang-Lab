use strict;
use warnings;
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);

# k-means-par: parallel variant of the k-means benchmark.
# Invocation: perl k-means-par.pl <cores> <n>
#
# The ASSIGNMENT step is parallelised: divide points into `cores` bands.
# Each worker receives the current centroids (K*D values) plus its slice of the
# points array, computes the nearest centroid for each point (strict-< tie-break,
# same as serial), and returns the assignment array together with per-cluster
# partial sums and counts via a pipe.
# The CENTROID UPDATE step runs serially in the parent by merging the partial
# sums/counts from all workers (floor-mean, empty cluster unchanged -- same as
# serial).
# Both the final assignment pass and the checksum are serial in the parent.

use constant {
    P      => 1000000007,
    K      => 16,
    D      => 4,
    ITERS  => 10,
    RANGE  => 256,
};

my $cores = @ARGV >= 1 ? int($ARGV[0]) : 1;
my $n     = @ARGV >= 2 ? int($ARGV[1]) : 8000;

# --- Generate points (LCG, same as serial) ---
my @pt;
my $state = 42;
for my $i (0 .. $n * D - 1) {
    $state = ($state * 1103515245 + 12345) & 0x7fffffff;
    $pt[$i] = $state % RANGE;
}

# Initial centroids = first K points.
my @cen;
for my $i (0 .. K * D - 1) {
    $cen[$i] = $pt[$i];
}

my @assign = (0) x $n;

# Helper: assign a band of points [pt_start, pt_end) to nearest centroid.
# Returns flat list: assignments (pt_end-pt_start values) followed by
# K*D partial sums and K partial counts.
sub assign_band {
    my ($pt_ref, $cen_ref, $pt_start, $pt_end) = @_;
    my @asgn;
    my @sum = (0) x (K * D);
    my @cnt = (0) x K;
    for my $i ($pt_start .. $pt_end - 1) {
        my $best = 0;
        my $bd   = -1;
        for my $k (0 .. K - 1) {
            my $dist = 0;
            for my $d (0 .. D - 1) {
                my $df = $pt_ref->[$i * D + $d] - $cen_ref->[$k * D + $d];
                $dist += $df * $df;
            }
            if ($bd < 0 || $dist < $bd) {
                $bd   = $dist;
                $best = $k;
            }
        }
        push @asgn, $best;
        $cnt[$best]++;
        for my $d (0 .. D - 1) {
            $sum[$best * D + $d] += $pt_ref->[$i * D + $d];
        }
    }
    return (@asgn, @sum, @cnt);
}

# --- ITERS iterations of assign + update ---
my $t0 = clock_gettime(CLOCK_MONOTONIC);
for (1 .. ITERS) {

    if ($cores == 1) {
        # Inline assignment.
        for my $i (0 .. $n - 1) {
            my $best = 0;
            my $bd   = -1;
            for my $k (0 .. K - 1) {
                my $dist = 0;
                for my $d (0 .. D - 1) {
                    my $df = $pt[$i * D + $d] - $cen[$k * D + $d];
                    $dist += $df * $df;
                }
                if ($bd < 0 || $dist < $bd) {
                    $bd   = $dist;
                    $best = $k;
                }
            }
            $assign[$i] = $best;
        }
    } else {
        # Parallel assignment: fork one worker per band.
        my @pipes;

        # Encode centroids as a newline-separated header so children can read them.
        # Worker receives centroids + its slice of pt.
        for my $w (0 .. $cores - 1) {
            my $pt_start = int($w * $n / $cores);
            my $pt_end   = int(($w + 1) * $n / $cores);

            pipe(my $rh, my $wh) or die "pipe: $!";

            my $pid = fork();
            die "fork: $!" unless defined $pid;

            if ($pid == 0) {
                # Child: compute assignment for [pt_start, pt_end).
                close $rh;
                my @results = assign_band(\@pt, \@cen, $pt_start, $pt_end);
                print $wh join("\n", @results), "\n";
                close $wh;
                exit 0;
            }

            close $wh;
            $pipes[$w] = [$rh, $pt_start, $pt_end];
        }

        # Collect: merge assignments, partial sums, partial counts.
        my @gsum = (0) x (K * D);
        my @gcnt = (0) x K;

        for my $w (0 .. $cores - 1) {
            my ($rh, $pt_start, $pt_end) = @{ $pipes[$w] };
            my $band_size = $pt_end - $pt_start;
            # Expected values: band_size assignments + K*D sums + K counts
            my $total = $band_size + K * D + K;
            my @vals;
            while (defined(my $line = readline($rh))) {
                chomp $line;
                push @vals, int($line);
                last if @vals == $total;
            }
            close $rh;

            # Assignments
            for my $i (0 .. $band_size - 1) {
                $assign[$pt_start + $i] = $vals[$i];
            }
            # Partial sums
            my $off = $band_size;
            for my $j (0 .. K * D - 1) {
                $gsum[$j] += $vals[$off + $j];
            }
            # Partial counts
            $off += K * D;
            for my $k (0 .. K - 1) {
                $gcnt[$k] += $vals[$off + $k];
            }
        }

        # Wait for all children.
        for (1 .. $cores) { wait() }

        # Serial centroid update (floor-mean, empty cluster unchanged).
        for my $k (0 .. K - 1) {
            if ($gcnt[$k] > 0) {
                for my $d (0 .. D - 1) {
                    $cen[$k * D + $d] = int($gsum[$k * D + $d] / $gcnt[$k]);
                }
            }
        }
        next;   # centroid update already done above; skip the serial update below
    }

    # Serial centroid update (runs only on the $cores==1 path).
    my @sum = (0) x (K * D);
    my @cnt = (0) x K;
    for my $i (0 .. $n - 1) {
        my $k = $assign[$i];
        $cnt[$k]++;
        for my $d (0 .. D - 1) {
            $sum[$k * D + $d] += $pt[$i * D + $d];
        }
    }
    for my $k (0 .. K - 1) {
        if ($cnt[$k] > 0) {
            for my $d (0 .. D - 1) {
                $cen[$k * D + $d] = int($sum[$k * D + $d] / $cnt[$k]);
            }
        }
    }
}
my $ns = int((clock_gettime(CLOCK_MONOTONIC) - $t0) * 1e9);
print STDERR "COMPUTE_NS $ns\n";

# --- Final assignment (serial, same as serial benchmark) ---
for my $i (0 .. $n - 1) {
    my $best = 0;
    my $bd   = -1;
    for my $k (0 .. K - 1) {
        my $dist = 0;
        for my $d (0 .. D - 1) {
            my $df = $pt[$i * D + $d] - $cen[$k * D + $d];
            $dist += $df * $df;
        }
        if ($bd < 0 || $dist < $bd) {
            $bd   = $dist;
            $best = $k;
        }
    }
    $assign[$i] = $best;
}

# --- Checksum (serial, same order as serial benchmark) ---
my $h = 0;
for my $i (0 .. K * D - 1) {
    $h = ($h * 31 + $cen[$i]) % P;
}
for my $i (0 .. $n - 1) {
    $h = ($h * 31 + $assign[$i]) % P;
}

print "$h\n";
print "k-means($n)\n";
