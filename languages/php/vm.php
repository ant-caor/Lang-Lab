<?php

// vm: a tiny stack-based bytecode virtual machine - the control-flow / interpreter-dispatch axis.
// Executes a FIXED program (the PROG array, shared verbatim by every language) that computes
// acc = (acc*31 + i*i) mod 2^32 over i in 0..N-1 with an explicit loop. The hot path is the dispatch
// loop (fetch opcode, branch, manipulate the stack) - the very thing that makes interpreters slow.
// PHP ints are 64-bit on 64-bit platforms (the MUL product reaches ~2^40); arithmetic ops mask to 32 bits.
// opcodes: 0 PUSH imm, 1 LOAD slot, 2 STORE slot, 3 ADD, 4 MUL, 5 SUB, 6 LT, 7 JZ addr, 8 JMP addr, 9 HALT

const P = 1000000007;
const MASK = 0xFFFFFFFF;

const PROG = [0,0,2,0,0,0,2,1,1,0,1,2,6,7,37,1,1,0,31,4,1,0,1,0,4,3,2,1,1,0,0,1,3,2,0,8,8,1,1,9];

function run(int $N): int {
    $stack = [];        // value stack
    $sp = 0;            // stack pointer
    $locals = [0, 0, $N]; // [i, acc, N]
    $pc = 0;
    $result = 0;
    for (;;) {
        $op = PROG[$pc++];
        if ($op === 0) {                // PUSH imm
            $stack[$sp++] = PROG[$pc++];
        } else if ($op === 1) {         // LOAD slot
            $stack[$sp++] = $locals[PROG[$pc++]];
        } else if ($op === 2) {         // STORE slot
            $locals[PROG[$pc++]] = $stack[--$sp];
        } else if ($op === 3) {         // ADD
            $b = $stack[--$sp]; $a = $stack[--$sp];
            $stack[$sp++] = ($a + $b) & MASK;
        } else if ($op === 4) {         // MUL
            $b = $stack[--$sp]; $a = $stack[--$sp];
            $stack[$sp++] = ($a * $b) & MASK;
        } else if ($op === 5) {         // SUB
            $b = $stack[--$sp]; $a = $stack[--$sp];
            $stack[$sp++] = ($a - $b) & MASK;
        } else if ($op === 6) {         // LT
            $b = $stack[--$sp]; $a = $stack[--$sp];
            $stack[$sp++] = ($a < $b) ? 1 : 0;
        } else if ($op === 7) {         // JZ addr
            $c = $stack[--$sp];
            if ($c === 0) $pc = PROG[$pc]; else $pc++;
        } else if ($op === 8) {         // JMP addr
            $pc = PROG[$pc];
        } else if ($op === 9) {         // HALT
            $result = $stack[$sp - 1];
            break;
        }
    }
    return $result;
}

$n = isset($argv[1]) ? (int)$argv[1] : 800000;
echo run($n) % P, "\n";
echo "vm($n)\n";
