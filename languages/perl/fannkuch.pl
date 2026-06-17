use strict;
use warnings;

sub fannkuch {
    my ($n) = @_;
    my @perm1 = (0 .. $n - 1);
    my @count = (0) x $n;
    my $max_flips = 0;
    my $checksum  = 0;
    my $perm_idx  = 0;
    my $r = $n;

    while (1) {
        while ($r != 1) {
            $count[$r - 1] = $r;
            $r--;
        }

        my @perm = @perm1;
        my $flips = 0;
        my $k = $perm[0];
        while ($k != 0) {
            my ($i, $j) = (0, $k);
            while ($i < $j) {
                @perm[$i, $j] = @perm[$j, $i];
                $i++;
                $j--;
            }
            $flips++;
            $k = $perm[0];
        }

        $max_flips = $flips if $flips > $max_flips;
        $checksum += ($perm_idx % 2 == 0) ? $flips : -$flips;

        # Generate the next permutation.
        while (1) {
            return ($max_flips, $checksum) if $r == $n;
            my $first = $perm1[0];
            for my $i (0 .. $r - 1) {
                $perm1[$i] = $perm1[$i + 1];
            }
            $perm1[$r] = $first;
            $count[$r]--;
            last if $count[$r] > 0;
            $r++;
        }
        $perm_idx++;
    }
}

my $n = @ARGV ? int($ARGV[0]) : 7;
my ($max_flips, $checksum) = fannkuch($n);
print "$checksum\n";
print "Pfannkuchen($n) = $max_flips\n";
