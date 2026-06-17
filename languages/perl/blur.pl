use strict;
use warnings;

# blur: a 2D image-convolution benchmark - the stencil axis of the suite. Generate a
# grayscale N x N image with a pinned LCG, then apply a 3x3 Gaussian blur kernel
# [1 2 1; 2 4 2; 1 2 1]/16 PASSES times (double-buffered), with clamp (edge-replication)
# border handling, and reduce the result to a polynomial hash. The stencil is a
# hand-written di/dj neighbourhood sum (NO image library / FFT / SIMD) over two mutable
# flat @arrays swapped by reference each pass. All integer arithmetic - no floating point.

use constant {
    P      => 1000000007,
    PASSES => 4,
};

# clamp(x, 0, N-1): edge replication - negative -> 0, >= N -> N-1.
sub clampi {
    my ($x, $n) = @_;
    return $x < 0 ? 0 : ($x >= $n ? $n - 1 : $x);
}

my $n = @ARGV ? int($ARGV[0]) : 256;

# 3x3 kernel, row-major, sum 16.
my @K = (1, 2, 1, 2, 4, 2, 1, 2, 1);

# Two mutable flat buffers (double-buffering); swap the refs each pass, never copy.
my @buf1;
my @buf2;
my $src = \@buf1;
my $dst = \@buf2;

# 1. Generate the N x N grayscale image (pixels 0..255) with the pinned LCG.
my $state = 42;
for my $k (0 .. $n * $n - 1) {
    $state = ($state * 1103515245 + 12345) & 0x7fffffff;
    $src->[$k] = $state % 256;
}

# 2. Apply the 3x3 blur PASSES times, double-buffered, clamping at the edges.
for (1 .. PASSES) {
    for my $i (0 .. $n - 1) {
        for my $j (0 .. $n - 1) {
            my $acc = 0;
            for my $di (-1 .. 1) {
                my $ni = clampi($i + $di, $n);       # clamp BOTH ni ...
                for my $dj (-1 .. 1) {
                    my $nj = clampi($j + $dj, $n);    # ... and nj
                    $acc += $K[($di + 1) * 3 + ($dj + 1)] * $src->[$ni * $n + $nj];
                }
            }
            $dst->[$i * $n + $j] = int($acc / 16);    # INTEGER (floor) division
        }
    }
    ($src, $dst) = ($dst, $src);                      # swap the refs (no copy)
}

# 3. Checksum: polynomial hash of the final image (src holds it after the last swap).
# 64-bit safe in Perl: h*31 ~3.1e10 stays exact well within the integer/double range.
my $h = 0;
for my $k (0 .. $n * $n - 1) {
    $h = ($h * 31 + $src->[$k]) % P;
}

print "$h\n";
print "blur($n)\n";
