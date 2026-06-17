use strict;
use warnings;

# sha256: iterated SHA-256 - the bit-manipulation / cryptography axis of the suite. Seed a
# 32-byte digest with a pinned LCG, then apply real FIPS 180-4 SHA-256 to it N times (each
# hash is one padded 512-bit block). The hot path is 32-bit rotations, XOR, shifts and modular
# 2^32 addition - work no other benchmark does. Hand-written (no Digest::SHA / crypto library);
# the checksum is a poly-hash of the final 32-byte digest. Perl ints are wider than 32 bits, so
# every word op is MASKED with & 0xFFFFFFFF; a right shift of a masked value is logical.

use constant P    => 1000000007;
use constant MASK => 0xFFFFFFFF;

my @K = (
  0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
  0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
  0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
  0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
  0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
  0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
  0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
  0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2);

my @H0 = (0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,
          0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19);

# rotr(x,n) on a 32-bit unsigned word: ($x is already masked, so >> is logical zero-fill).
sub rotr {
    my ($x, $n) = @_;
    return (($x >> $n) | ($x << (32 - $n))) & MASK;
}

# Hash the 32-byte digest in place: one padded 64-byte block (message length = 256 bits).
sub sha256_32 {
    my ($d) = @_;

    # Build the 64-byte block: 32 digest bytes, then 0x80, zeros, and the big-endian length.
    my @b = (@$d, 0x80, (0) x 31);   # b[32]=0x80; b[33..63]=0
    $b[62] = 1;                      # length 256 = 0x0100 -> b[62]=1, b[63]=0

    # 16 words, big-endian.
    my @w;
    for my $i (0 .. 15) {
        $w[$i] = (($b[$i*4] << 24) | ($b[$i*4+1] << 16) | ($b[$i*4+2] << 8) | $b[$i*4+3]) & MASK;
    }
    # Message schedule i=16..63 (>>3 and >>10 are logical on masked words).
    for my $i (16 .. 63) {
        my $s0 = rotr($w[$i-15], 7) ^ rotr($w[$i-15], 18) ^ ($w[$i-15] >> 3);
        my $s1 = rotr($w[$i-2], 17) ^ rotr($w[$i-2], 19) ^ ($w[$i-2] >> 10);
        $w[$i] = ($w[$i-16] + $s0 + $w[$i-7] + $s1) & MASK;
    }

    my ($a, $bb, $c, $dd, $e, $f, $g, $hh) = @H0;
    for my $i (0 .. 63) {
        my $S1  = rotr($e, 6) ^ rotr($e, 11) ^ rotr($e, 25);
        my $ch  = ($e & $f) ^ ((~$e & MASK) & $g);
        my $t1  = ($hh + $S1 + $ch + $K[$i] + $w[$i]) & MASK;
        my $S0  = rotr($a, 2) ^ rotr($a, 13) ^ rotr($a, 22);
        my $maj = ($a & $bb) ^ ($a & $c) ^ ($bb & $c);
        my $t2  = ($S0 + $maj) & MASK;
        $hh = $g; $g = $f; $f = $e; $e = ($dd + $t1) & MASK;
        $dd = $c; $c = $bb; $bb = $a; $a = ($t1 + $t2) & MASK;
    }

    my @h = (
        ($H0[0] + $a)  & MASK, ($H0[1] + $bb) & MASK, ($H0[2] + $c) & MASK, ($H0[3] + $dd) & MASK,
        ($H0[4] + $e)  & MASK, ($H0[5] + $f)  & MASK, ($H0[6] + $g) & MASK, ($H0[7] + $hh) & MASK,
    );

    # Serialize the 8 words big-endian back into the 32-byte digest.
    for my $i (0 .. 7) {
        $d->[$i*4]   = ($h[$i] >> 24) & 0xff;
        $d->[$i*4+1] = ($h[$i] >> 16) & 0xff;
        $d->[$i*4+2] = ($h[$i] >> 8)  & 0xff;
        $d->[$i*4+3] = $h[$i]         & 0xff;
    }
}

my $N = @ARGV ? int($ARGV[0]) : 10000;

# Seed the 32-byte digest with the pinned LCG.
my @d;
my $s = 42;
for my $i (0 .. 31) {
    $s = ($s * 1103515245 + 12345) & 0x7fffffff;
    $d[$i] = $s % 256;
}

sha256_32(\@d) for 1 .. $N;

# Checksum: polynomial hash of the final digest.
my $h = 0;
$h = ($h * 31 + $_) % P for @d;

print "$h\n";
print "sha256($N)\n";
