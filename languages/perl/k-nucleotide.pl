use strict;
use warnings;

use constant {
    K  => 8,
    P  => 1000000007,
    IM => 139968,
    IA => 3877,
    IC => 29573,
};

# Deterministic DNA sequence via an integer LCG (no floating point).
sub gen {
    my ($len) = @_;
    my $seed = 42;
    my $s = '';
    for (1 .. $len) {
        $seed = ($seed * IA + IC) % IM;
        $s .= $seed < 42000 ? 'A' : $seed < 70000 ? 'C' : $seed < 98000 ? 'G' : 'T';
    }
    return $s;
}

sub k_nucleotide {
    my ($len) = @_;
    my $s = gen($len);

    # Count every K-mer in a hash keyed by the K-character substring.
    my %counts;
    for my $i (0 .. $len - K) {
        $counts{ substr($s, $i, K) }++;
    }

    # Order-independent checksum: sum of encode(kmer)*count mod P.
    my %code = (A => 0, C => 1, G => 2, T => 3);
    my $acc = 0;
    while (my ($kmer, $count) = each %counts) {
        my $e = 0;
        $e = $e * 4 + $code{$_} for split //, $kmer;   # big-endian decode
        $acc = ($acc + $e * $count) % P;
    }
    return $acc;
}

my $n = @ARGV ? int($ARGV[0]) : 100000;
print k_nucleotide($n), "\n";
print "k-nucleotide($n)\n";
