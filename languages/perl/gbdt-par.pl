use strict;
use warnings;
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);

# gbdt-par: parallel variant of the gbdt benchmark.
# Invocation: perl gbdt-par.pl <cores> <n>
#
# The N samples are divided into `cores` bands.  Each worker evaluates all B
# trees for its band of samples and returns the per-sample acc values via a
# pipe.  The parent collects in band order and runs the serial checksum pass
# over the reconstructed acc array, producing output identical to the serial
# benchmark for any core count.
#
# Tree arrays (feat, thr, leafval) are built in the parent before forking and
# are read-only in the children (copy-on-write fork semantics).

use constant {
    P          => 1000000007,
    D          => 8,
    B          => 200,
    F          => 8,
    NODES      => 511,
    LEAF_START => 255,
};

my $cores = @ARGV >= 1 ? int($ARGV[0]) : 1;
my $n     = @ARGV >= 2 ? int($ARGV[1]) : 5000;

# --- Build trees (LCG, same as serial) ---
my @feat;
my @thr;
my @leafval;

my $state = 42;
for my $b (0 .. B - 1) {
    my $base = $b * NODES;
    for my $node (0 .. LEAF_START - 1) {
        $state = ($state * 1103515245 + 12345) & 0x7fffffff;
        $feat[$base + $node] = $state % F;
        $state = ($state * 1103515245 + 12345) & 0x7fffffff;
        $thr[$base + $node]  = $state % 256;
    }
    for my $node (LEAF_START .. NODES - 1) {
        $state = ($state * 1103515245 + 12345) & 0x7fffffff;
        $leafval[$base + $node] = $state % 10;
    }
}

# --- Generate samples (LCG continues, same as serial) ---
my @sample;
for my $i (0 .. $n * F - 1) {
    $state = ($state * 1103515245 + 12345) & 0x7fffffff;
    $sample[$i] = $state % 256;
}

# Helper: evaluate all B trees for samples [s_start, s_end), return acc values.
sub eval_band {
    my ($s_start, $s_end) = @_;
    my @accs;
    for my $i ($s_start .. $s_end - 1) {
        my $sbase = $i * F;
        my $acc   = 0;
        for my $b (0 .. B - 1) {
            my $tbase = $b * NODES;
            my $node  = 0;
            for (1 .. D) {
                if ($sample[$sbase + $feat[$tbase + $node]] <= $thr[$tbase + $node]) {
                    $node = 2 * $node + 1;
                } else {
                    $node = 2 * $node + 2;
                }
            }
            $acc += $leafval[$tbase + $node];
        }
        push @accs, $acc;
    }
    return @accs;
}

if ($cores == 1) {
    # Inline path.
    my $t0 = clock_gettime(CLOCK_MONOTONIC);
    my @accs = eval_band(0, $n);
    my $ns = int((clock_gettime(CLOCK_MONOTONIC) - $t0) * 1e9);
    print STDERR "COMPUTE_NS $ns\n";
    my $h     = 0;
    my $total = 0;
    for my $i (0 .. $n - 1) {
        $h     = ($h * 31 + $accs[$i] + 1) % P;
        $total = ($total + $accs[$i])       % P;
    }
    print "$h\n";
    print "gbdt($n) = $total\n";
    exit 0;
}

# --- Parallel path: fork one worker per sample band ---
my @pipes;

my $t0 = clock_gettime(CLOCK_MONOTONIC);

for my $w (0 .. $cores - 1) {
    my $s_start = int($w * $n / $cores);
    my $s_end   = int(($w + 1) * $n / $cores);

    pipe(my $rh, my $wh) or die "pipe: $!";

    my $pid = fork();
    die "fork: $!" unless defined $pid;

    if ($pid == 0) {
        # Child
        close $rh;
        my @accs = eval_band($s_start, $s_end);
        print $wh join("\n", @accs), "\n";
        close $wh;
        exit 0;
    }

    close $wh;
    $pipes[$w] = [$rh, $s_start, $s_end];
}

# Collect acc values in band order into a flat array indexed by sample.
my @accs = (0) x $n;
for my $w (0 .. $cores - 1) {
    my ($rh, $s_start, $s_end) = @{ $pipes[$w] };
    my $band_size = $s_end - $s_start;
    my @vals;
    while (defined(my $line = readline($rh))) {
        chomp $line;
        push @vals, int($line);
        last if @vals == $band_size;
    }
    close $rh;
    for my $i (0 .. $band_size - 1) {
        $accs[$s_start + $i] = $vals[$i];
    }
}

# Wait for all children.
for (1 .. $cores) { wait() }

my $ns = int((clock_gettime(CLOCK_MONOTONIC) - $t0) * 1e9);
print STDERR "COMPUTE_NS $ns\n";

# --- Checksum pass (serial, same order as serial benchmark) ---
my $h     = 0;
my $total = 0;
for my $i (0 .. $n - 1) {
    $h     = ($h * 31 + $accs[$i] + 1) % P;
    $total = ($total + $accs[$i])       % P;
}

print "$h\n";
print "gbdt($n) = $total\n";
