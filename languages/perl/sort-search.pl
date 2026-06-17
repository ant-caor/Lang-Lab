use strict;
use warnings;

# sort-search: generate N integers with a pinned LCG, sort them with a hand-written
# median-of-three quicksort (Hoare partition), then run N binary searches and fold the
# found indices into a checksum. Both classic algorithms are written out by hand (no
# stdlib sort/bsearch), so this measures the LANGUAGE running the SAME algorithm. All
# integer; @array is the single mutable array, sorted in place.

use constant P => 1000000007;

# median-of-three + Hoare partition, recurse both sides; depth stays ~log N.
sub qsort_h {
    my ($a, $lo, $hi) = @_;
    return if $lo >= $hi;
    my $mid = $lo + int(($hi - $lo) / 2);          # INTEGER (floor) division
    @$a[$lo, $mid] = @$a[$mid, $lo] if $a->[$mid] < $a->[$lo];
    @$a[$lo, $hi]  = @$a[$hi, $lo]  if $a->[$hi]  < $a->[$lo];
    @$a[$mid, $hi] = @$a[$hi, $mid] if $a->[$hi]  < $a->[$mid];
    my $pivot = $a->[$mid];
    my $i = $lo - 1;
    my $j = $hi + 1;
    while (1) {
        do { $i++ } while $a->[$i] < $pivot;       # Hoare scan: bump first, then test
        do { $j-- } while $a->[$j] > $pivot;
        last if $i >= $j;
        @$a[$i, $j] = @$a[$j, $i];
    }
    qsort_h($a, $lo, $j);                           # recurse lo..j THEN j+1..hi
    qsort_h($a, $j + 1, $hi);
}

sub bsearch_i {
    my ($a, $n, $key) = @_;
    my $lo = 0;
    my $hi = $n - 1;
    while ($lo <= $hi) {
        my $mid = $lo + int(($hi - $lo) / 2);       # INTEGER division
        if    ($a->[$mid] < $key) { $lo = $mid + 1 }
        elsif ($a->[$mid] > $key) { $hi = $mid - 1 }
        else                      { return $mid }
    }
    return -1;
}

my $n = @ARGV ? int($ARGV[0]) : 100000;

my @a;
my $state = 42;
for my $i (0 .. $n - 1) {
    $state = ($state * 1103515245 + 12345) & 0x7fffffff;
    $a[$i] = $state;
}

qsort_h(\@a, 0, $n - 1);

my $h = 0;
for my $q (0 .. $n - 1) {
    $state = ($state * 1103515245 + 12345) & 0x7fffffff;   # CONTINUE the same LCG stream
    my $key = $a[$state % $n];                              # a value present -> a hit
    my $idx = bsearch_i(\@a, $n, $key);
    $h = ($h * 31 + ($idx + 1)) % P;
}

print "$h\n";
print "sort-search($n)\n";
