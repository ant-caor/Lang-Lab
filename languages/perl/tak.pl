use strict;
use warnings;

my $calls = 0;

sub tak {
    my ($x, $y, $z) = @_;
    $calls++;
    return $z if $y >= $x;
    return tak(tak($x - 1, $y, $z), tak($y - 1, $z, $x), tak($z - 1, $x, $y));
}

my $n = @ARGV ? int($ARGV[0]) : 6;
my $r = tak(3 * $n, 2 * $n, $n);
print "$calls\n";
print "tak($n) = $r\n";
