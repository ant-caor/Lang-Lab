use strict;
use warnings;

# polymorphism: dynamic-dispatch / virtual-call-overhead axis. N objects of K=6 concrete types in
# an unpredictable (megamorphic) order; fold acc through all of them M times via $obj->apply($acc).
# Each type is its own package (bless) with its own apply method; which one runs is resolved at
# RUNTIME by Perl's method dispatch on the object's package. The acc threads through every call so
# nothing can be hoisted (exactly N*M real dispatches). Checksum = the final accumulator. Integer.
use constant { P => 1000000007, N => 10000, K => 6 };

# Six per-type packages: same fields {a,b,c}, distinct large multipliers so the per-pass map never
# reaches a fixed point (acc stays chaotic, checksum depends on M -> all N*M dispatches really ran).
package T0; sub new { bless { a => $_[1], b => $_[2], c => $_[3] }, $_[0] }
           sub apply { ($_[1] * 1000003 + $_[0]{a}) % main::P }
package T1; our @ISA = ('T0'); sub apply { ($_[1] * 998273 + $_[0]{b}) % main::P }
package T2; our @ISA = ('T0'); sub apply { ($_[1] * 999983 + $_[0]{c}) % main::P }
package T3; our @ISA = ('T0'); sub apply { ($_[1] * 997879 + $_[0]{a} + $_[0]{b}) % main::P }
package T4; our @ISA = ('T0'); sub apply { ($_[1] * 996323 + $_[0]{b} * $_[0]{c}) % main::P }
package T5; our @ISA = ('T0'); sub apply { ($_[1] * 995369 + $_[0]{a} + $_[0]{c}) % main::P }

package main;

my @TYPES = ('T0', 'T1', 'T2', 'T3', 'T4', 'T5');

sub lcg { ($_[0] * 1103515245 + 12345) & 0x7fffffff }

my $M = @ARGV ? int($ARGV[0]) : 50;
my $s = 42;
my @objs;
for (1 .. N) {
    $s = lcg($s); my $t = ($s >> 16) % K;   # type from HIGH bits (LCG low bits correlate); all K used
    $s = lcg($s); my $a = $s % 1000;
    $s = lcg($s); my $b = $s % 1000;
    $s = lcg($s); my $c = $s % 1000;
    push @objs, $TYPES[$t]->new($a, $b, $c);
}
my $acc = 1;
for (1 .. $M) {
    for my $o (@objs) {
        $acc = $o->apply($acc);   # DYNAMIC dispatch (runtime method resolution per object)
    }
}
print "$acc\n";
print "polymorphism($M)\n";
