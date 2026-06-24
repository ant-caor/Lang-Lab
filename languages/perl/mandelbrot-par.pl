use strict;
use warnings;
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);

# mandelbrot-par: parallel variant of the mandelbrot benchmark.
# Invocation: perl mandelbrot-par.pl <cores> <n>
# Decomposes the N rows into `cores` horizontal bands; each worker (fork)
# computes the in-set count for its band and returns it to the parent via a
# pipe.  Output is bit-identical to the serial benchmark for any core count.

sub mandelbrot_band {
    my ($n, $row_start, $row_end) = @_;
    my $count = 0;
    for my $y ($row_start .. $row_end - 1) {
        my $ci = 2.0 * $y / $n - 1.0;
        for my $x (0 .. $n - 1) {
            my $cr = 2.0 * $x / $n - 1.5;
            my ($zr, $zi, $tr, $ti) = (0.0, 0.0, 0.0, 0.0);
            my $i = 0;
            while ($i < 50 && $tr + $ti <= 4.0) {
                my $t = $zr * $zi;
                $zi = $t + $t + $ci;   # == 2*zr*zi + ci, FMA-proof
                $zr = $tr - $ti + $cr;
                $tr = $zr * $zr;
                $ti = $zi * $zi;
                $i++;
            }
            $count++ if $tr + $ti <= 4.0;
        }
    }
    return $count;
}

my $cores = @ARGV >= 1 ? int($ARGV[0]) : 1;
my $n     = @ARGV >= 2 ? int($ARGV[1]) : 128;

if ($cores == 1) {
    # Inline path: no fork overhead.
    my $t0 = clock_gettime(CLOCK_MONOTONIC);
    my $count = mandelbrot_band($n, 0, $n);
    my $ns = int((clock_gettime(CLOCK_MONOTONIC) - $t0) * 1e9);
    print STDERR "COMPUTE_NS $ns\n";
    print "$count\n";
    print "mandelbrot($n)\n";
    exit 0;
}

# Fork one child per band.  Each child writes its count as a decimal line to
# its write-end of a pipe and exits.  Parent reads from all pipes in order,
# sums, then prints.
my @pipes;   # $pipes[$w] = read filehandle for worker $w

my $t0 = clock_gettime(CLOCK_MONOTONIC);

for my $w (0 .. $cores - 1) {
    my $row_start = int($w * $n / $cores);
    my $row_end   = int(($w + 1) * $n / $cores);

    pipe(my $rh, my $wh) or die "pipe: $!";

    my $pid = fork();
    die "fork: $!" unless defined $pid;

    if ($pid == 0) {
        # Child
        close $rh;
        my $count = mandelbrot_band($n, $row_start, $row_end);
        print $wh "$count\n";
        close $wh;
        exit 0;
    }

    # Parent
    close $wh;
    $pipes[$w] = $rh;
}

# Collect results in band order (preserves deterministic ordering).
my $total = 0;
for my $w (0 .. $cores - 1) {
    my $line = readline($pipes[$w]);
    chomp $line;
    $total += int($line);
    close $pipes[$w];
}

# Wait for all children.
for (1 .. $cores) { wait() }

my $ns = int((clock_gettime(CLOCK_MONOTONIC) - $t0) * 1e9);
print STDERR "COMPUTE_NS $ns\n";

print "$total\n";
print "mandelbrot($n)\n";
