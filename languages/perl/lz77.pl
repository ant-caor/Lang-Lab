use strict;
use warnings;

# lz77: a hand-written LZ77 compressor - the data-compression / sliding-window axis.
# Generate N bytes from a small alphabet with a pinned LCG (so matches are common), then
# compress greedily: at each position scan the previous WINDOW bytes for the longest
# match of the lookahead (closest distance wins ties), emit a (distance, length) back-
# reference or a literal, advance by the match length. Reduce the token stream to a
# polynomial hash. The window scan is the explicit brute-force O(N*WINDOW) loop written
# out by hand (NO compression library, no hash-chain / suffix-tree acceleration), so this
# measures Perl running the SAME algorithm. All integer; @in is the input byte array.

use constant {
    P         => 1000000007,
    WINDOW    => 512,
    MIN_MATCH => 3,
    MAX_MATCH => 255,
    ALPHA     => 6,
};

my $n = @ARGV ? int($ARGV[0]) : 24000;

# Generate N bytes (small alphabet) with the pinned glibc-style LCG.
my @in;
my $state = 42;
for my $i (0 .. $n - 1) {
    $state = ($state * 1103515245 + 12345) & 0x7fffffff;
    $in[$i] = $state % ALPHA;
}

# Greedy LZ77 parse folded into a 64-bit polynomial hash (h*31 ~3.1e10 stays exact in
# Perl's integer/double range; %P keeps it small after each step).
my $pos = 0;
my $h   = 0;
while ($pos < $n) {
    my $best_len  = 0;
    my $best_dist = 0;
    my $start = $pos - WINDOW;
    $start = 0 if $start < 0;
    for (my $cand = $pos - 1; $cand >= $start; $cand--) {   # closest distance first
        my $l = 0;
        while ($pos + $l < $n && $l < MAX_MATCH && $in[$cand + $l] == $in[$pos + $l]) {
            $l++;
        }
        if ($l > $best_len) {                               # strict > : closest wins ties
            $best_len  = $l;
            $best_dist = $pos - $cand;
        }
    }
    if ($best_len >= MIN_MATCH) {                           # emit a back-reference
        $h = ($h * 31 + 1) % P;
        $h = ($h * 31 + $best_dist) % P;
        $h = ($h * 31 + $best_len) % P;
        $pos += $best_len;
    } else {                                                # emit a literal
        $h = ($h * 31 + 0) % P;
        $h = ($h * 31 + $in[$pos]) % P;
        $pos += 1;
    }
}

print "$h\n";
print "lz77($n)\n";
