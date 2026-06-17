use strict;
use warnings;

# Hand-rolled multi-precision N! as an array of base-2^32 limbs (least-significant
# first). Repeated bignum*smallint multiply: cur = limb*k + carry (exact in Perl's
# 64-bit IV - reaches ~2^46 for these N), store the low 32 bits, propagate the high
# bits as carry. NO native/library bignum (no Math::BigInt) - the accumulator IS the
# @limbs array, masked & 0xFFFFFFFF and shifted >> 32 by hand. Then poly-hash the limbs.
use constant P => 1000000007;
use constant MASK => 0xFFFFFFFF;

sub bigint {
    my ($n) = @_;
    my @limbs = (1);
    for (my $k = 2; $k <= $n; $k++) {
        my $carry = 0;
        for my $i (0 .. $#limbs) {
            my $cur = $limbs[$i] * $k + $carry;   # 64-bit intermediate
            $limbs[$i] = $cur & MASK;             # low 32 bits
            $carry = $cur >> 32;                  # high bits propagate
        }
        while ($carry > 0) {
            push @limbs, $carry & MASK;
            $carry = $carry >> 32;
        }
    }
    my $h = 0;
    for my $limb (@limbs) {                       # least-significant first
        $h = ($h * 31 + $limb) % P;
    }
    return $h;
}

my $n = @ARGV ? int($ARGV[0]) : 6000;
print bigint($n), "\n";
print "bigint($n)\n";
