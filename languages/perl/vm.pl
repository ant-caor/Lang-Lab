use strict;
use warnings;

# vm: a tiny stack-based bytecode virtual machine - the control-flow / interpreter-dispatch axis.
# Runs a FIXED 40-int program (PROG, shared verbatim by every language) that computes
# acc = (acc*31 + i*i) mod 2^32 over i in 0..N-1 with an explicit loop. The hot path is the
# dispatch loop: fetch opcode, branch, push/pop the stack - interpreted opcode by opcode.
# VM values are 64-bit (Perl IV/UV on a 64-bit build); the MUL product reaches ~2^40 before
# masking, so it stays exact. ADD/SUB/MUL mask to 32 bits.

use constant {
    P    => 1000000007,
    MASK => 0xFFFFFFFF,
};

# opcodes: 0 PUSH imm, 1 LOAD slot, 2 STORE slot, 3 ADD, 4 MUL, 5 SUB, 6 LT, 7 JZ addr, 8 JMP addr, 9 HALT
my @PROG = (0,0,2,0,0,0,2,1,1,0,1,2,6,7,37,1,1,0,31,4,1,0,1,0,4,3,2,1,1,0,0,1,3,2,0,8,8,1,1,9);

sub run {
    my ($N) = @_;
    my @stack;                 # operand stack
    my @locals = (0, 0, $N);   # locals = [i, acc, N]
    my $pc = 0;
    my $result = 0;

    for (;;) {
        my $op = $PROG[$pc++];
        if ($op == 0) {                                    # PUSH imm
            push @stack, $PROG[$pc++];
        } elsif ($op == 1) {                               # LOAD slot
            push @stack, $locals[$PROG[$pc++]];
        } elsif ($op == 2) {                               # STORE slot
            $locals[$PROG[$pc++]] = pop @stack;
        } elsif ($op == 3) {                               # ADD
            my $b = pop @stack; my $a = pop @stack;
            push @stack, ($a + $b) & MASK;
        } elsif ($op == 4) {                               # MUL
            my $b = pop @stack; my $a = pop @stack;
            push @stack, ($a * $b) & MASK;
        } elsif ($op == 5) {                               # SUB
            my $b = pop @stack; my $a = pop @stack;
            push @stack, ($a - $b) & MASK;
        } elsif ($op == 6) {                               # LT
            my $b = pop @stack; my $a = pop @stack;
            push @stack, ($a < $b) ? 1 : 0;
        } elsif ($op == 7) {                               # JZ addr
            my $c = pop @stack;
            if ($c == 0) { $pc = $PROG[$pc]; } else { $pc++; }
        } elsif ($op == 8) {                               # JMP addr
            $pc = $PROG[$pc];
        } elsif ($op == 9) {                               # HALT
            $result = $stack[-1];
            last;
        }
    }
    return $result;
}

my $n = @ARGV ? int($ARGV[0]) : 800000;
print run($n) % P, "\n";
print "vm($n)\n";
