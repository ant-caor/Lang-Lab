use strict;
use warnings;

# Each node is a 2-element array ref [left, right] - a real heap allocation.
sub make {
    my ($depth) = @_;
    return [undef, undef] if $depth == 0;
    return [make($depth - 1), make($depth - 1)];
}

sub check {
    my ($node) = @_;
    return 1 unless defined $node->[0];
    return 1 + check($node->[0]) + check($node->[1]);
}

sub binary_trees {
    my ($n) = @_;
    my $min_depth = 4;
    my $max_depth = $min_depth + 2 > $n ? $min_depth + 2 : $n;
    my $stretch_depth = $max_depth + 1;

    my $total = check(make($stretch_depth));
    my $long_lived = make($max_depth);

    my $depth = $min_depth;
    while ($depth <= $max_depth) {
        my $iterations = 1 << ($max_depth - $depth + $min_depth);
        my $s = 0;
        for (1 .. $iterations) {
            $s += check(make($depth));
        }
        $total += $s;
        $depth += 2;
    }

    $total += check($long_lived);
    return $total;
}

my $n = @ARGV ? int($ARGV[0]) : 10;
print binary_trees($n), "\n";
print "binary-trees($n)\n";
