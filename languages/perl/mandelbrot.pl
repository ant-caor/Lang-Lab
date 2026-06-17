use strict;
use warnings;

# Mandelbrot set over an N x N grid of the complex plane [-1.5, 0.5] x [-1.0, 1.0].
# A pixel is "in the set" if |z| stays <= 2 (zr^2+zi^2 <= 4) through 50 iterations
# of z := z^2 + c starting from z = 0. The checksum is the count of in-set pixels.
#
# Perl NV is IEEE-754 double on a standard build. The 2*zr*zi term is written as
# t+t (t = zr*zi) instead of 2.0*zr*zi so there is NO multiply-add pattern to FMA-
# contract; t+t is bit-identical to 2.0*t, keeping the result bit-exact everywhere.
sub mandelbrot {
    my ($n) = @_;
    my $count = 0;
    for my $y (0 .. $n - 1) {
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
            $count++ if $tr + $ti <= 4.0;   # never escaped -> in set
        }
    }
    return $count;
}

my $n = @ARGV ? int($ARGV[0]) : 128;
print mandelbrot($n), "\n";
print "mandelbrot($n)\n";
