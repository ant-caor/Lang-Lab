use strict;
use warnings;

# reverse-complement: generate a DNA sequence, reverse it in place while complementing
# each base (A<->T, C<->G), then reduce it to a polynomial string hash. The reverse is a
# hand-written two-pointer loop (NOT a stdlib reverse) and the hash a per-character loop
# (NOT a builtin), so this measures Perl's own per-character processing. All integer.

use constant {
    P  => 1000000007,
    IM => 139968,
    IA => 3877,
    IC => 29573,
};

# comp: A<->T, C<->G; only A/C/G/T occur. Works on an ASCII byte value, returns one.
sub comp {
    my ($c) = @_;
    return $c == ord('A') ? ord('T')
         : $c == ord('C') ? ord('G')
         : $c == ord('G') ? ord('C')
         :                   ord('A');
}

my $L = @ARGV ? int($ARGV[0]) : 100000;

# Mutable byte buffer: a Perl string indexed in place via substr (strings are mutable).
my $s = "\0" x $L;
my $seed = 42;
for (my $i = 0; $i < $L; $i++) {
    $seed = ($seed * IA + IC) % IM;
    my $ch = $seed < 42000 ? 'A' : $seed < 70000 ? 'C' : $seed < 98000 ? 'G' : 'T';
    substr($s, $i, 1) = $ch;
}

# Hand-written two-pointer reverse-and-complement, in place.
my $i = 0;
my $j = $L - 1;
while ($i < $j) {
    my $a = comp(ord(substr($s, $i, 1)));
    substr($s, $i, 1) = chr(comp(ord(substr($s, $j, 1))));
    substr($s, $j, 1) = chr($a);
    $i++;
    $j--;
}
if ($i == $j) {
    substr($s, $i, 1) = chr(comp(ord(substr($s, $i, 1))));
}

# Hand-written polynomial string hash over the ASCII byte values (64-bit safe in Perl:
# integers carry to doubles/64-bit, and h*31 ~3.1e10 stays exact well within that range).
my $h = 0;
for (my $k = 0; $k < $L; $k++) {
    $h = ($h * 31 + ord(substr($s, $k, 1))) % P;
}

print "$h\n";
print "reverse-complement($L)\n";
