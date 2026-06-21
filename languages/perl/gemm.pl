use strict;
use warnings;

# gemm: quantized integer matrix-multiply - the dominant ML inference kernel.
# Square matmul of side N (i.e. N x N matrices). Loop order i,k,j (pinned)
# so B is accessed row-sequentially. LCG fills A then B with values 0..127.
# Accumulator is 64-bit; checksum = poly-hash of C row-major mod 1e9+7.
# No BLAS / no library matmul - the explicit triple loop.

use constant P => 1000000007;

my $n = @ARGV ? int($ARGV[0]) : 256;

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

my @C = (0) x ($n * $n);

# Pinned loop order i, k, j - B read row-sequentially.
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

my $h = 0;
for my $i (0 .. $n * $n - 1) {
    $h = ($h * 31 + $C[$i] % P) % P;
}
my $secondary = $C[$n * $n - 1] % P;

print "$h\n";
print "gemm($n) = $secondary\n";
