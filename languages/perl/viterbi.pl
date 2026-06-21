use strict;
use warnings;

# viterbi: integer HMM sequence decoding — the classical max-plus trellis.
# S=8 states, ALPHA=4 symbols, T=size parameter. LCG (glibc-style, seed=42)
# draws trans[S*S], emit[S*ALPHA], obs[T] in that order. Forward pass is a
# loop-carried max-reduction (STRICT > tie-break: lowest i wins), followed by
# a pointer-chain backtrace. Checksum = poly-hash of (path[t]+1).
# Secondary = optimal total path score mod P. No HMM library; pure integer.

use constant {
    S     => 8,
    ALPHA => 4,
    P     => 1000000007,
};

my $t = @ARGV ? int($ARGV[0]) : 20000;

# Draw order: trans[S*S], emit[S*ALPHA], obs[T]
my @trans;
my @emit;
my @obs;
my $state = 42;
for my $x (0 .. S * S - 1) {
    $state = ($state * 1103515245 + 12345) & 0x7fffffff;
    $trans[$x] = $state % 100 + 1;
}
for my $x (0 .. S * ALPHA - 1) {
    $state = ($state * 1103515245 + 12345) & 0x7fffffff;
    $emit[$x] = $state % 100 + 1;
}
for my $i (0 .. $t - 1) {
    $state = ($state * 1103515245 + 12345) & 0x7fffffff;
    $obs[$i] = $state % ALPHA;
}

# Initialise t=0
my @vit_prev;
for my $j (0 .. S - 1) {
    $vit_prev[$j] = $emit[$j * ALPHA + $obs[0]];
}

# back[t*S+j]
my @back = (0) x ($t * S);

# Forward trellis t=1..T-1
my @vit_next = (0) x S;
for my $ti (1 .. $t - 1) {
    for my $j (0 .. S - 1) {
        my $best = -1;
        my $bi = 0;
        my $e = $emit[$j * ALPHA + $obs[$ti]];
        for my $i (0 .. S - 1) {
            my $sc = $vit_prev[$i] + $trans[$i * S + $j] + $e;
            if ($sc > $best) {   # STRICT > -> lowest i wins
                $best = $sc;
                $bi = $i;
            }
        }
        $vit_next[$j] = $best;
        $back[$ti * S + $j] = $bi;
    }
    @vit_prev = @vit_next;
}

# Final state: STRICT > -> lowest j wins
my $bf = 0;
for my $j (1 .. S - 1) {
    if ($vit_prev[$j] > $vit_prev[$bf]) { $bf = $j; }
}

# Backtrace
my @path = (0) x $t;
$path[$t - 1] = $bf;
for my $ti (reverse 0 .. $t - 2) {
    $path[$ti] = $back[($ti + 1) * S + $path[$ti + 1]];
}

# Checksum
my $h = 0;
for my $ti (0 .. $t - 1) {
    $h = ($h * 31 + $path[$ti] + 1) % P;
}

my $secondary = $vit_prev[$bf] % P;
print "$h\n";
print "viterbi($t) = $secondary\n";
