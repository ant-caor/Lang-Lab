// vm: a tiny stack-based bytecode virtual machine - the control-flow / interpreter-dispatch axis.
// Executes a FIXED program (the PROG array, shared verbatim by every language) that computes
// acc = (acc*31 + i*i) mod 2^32 over i in 0..N-1 with an explicit loop. The hot path is the dispatch
// loop (fetch opcode, branch, manipulate the stack) - the very thing that makes interpreters slow.
// All VM values are 64-bit (products fit); arithmetic ops mask to 32 bits.
use std::env;

const P: i64 = 1000000007;
const MASK: i64 = 0xFFFFFFFF;

// opcodes: 0 PUSH imm, 1 LOAD slot, 2 STORE slot, 3 ADD, 4 MUL, 5 SUB, 6 LT, 7 JZ addr, 8 JMP addr, 9 HALT
const PROG: [i64; 40] = [
    0, 0, 2, 0, 0, 0, 2, 1, 1, 0, 1, 2, 6, 7, 37, 1, 1, 0, 31, 4, 1, 0, 1, 0, 4, 3, 2, 1, 1, 0, 0,
    1, 3, 2, 0, 8, 8, 1, 1, 9,
];

fn run(n: i64) -> i64 {
    let mut stack: Vec<i64> = Vec::with_capacity(64);
    let mut locals: [i64; 3] = [0, 0, n];
    let mut pc: usize = 0;
    let result: i64;
    loop {
        let op = PROG[pc];
        pc += 1;
        if op == 0 {
            stack.push(PROG[pc]);
            pc += 1;
        } else if op == 1 {
            stack.push(locals[PROG[pc] as usize]);
            pc += 1;
        } else if op == 2 {
            locals[PROG[pc] as usize] = stack.pop().unwrap();
            pc += 1;
        } else if op == 3 {
            let b = stack.pop().unwrap();
            let a = stack.pop().unwrap();
            stack.push((a + b) & MASK);
        } else if op == 4 {
            let b = stack.pop().unwrap();
            let a = stack.pop().unwrap();
            stack.push((a * b) & MASK);
        } else if op == 5 {
            let b = stack.pop().unwrap();
            let a = stack.pop().unwrap();
            stack.push((a - b) & MASK);
        } else if op == 6 {
            let b = stack.pop().unwrap();
            let a = stack.pop().unwrap();
            stack.push(if a < b { 1 } else { 0 });
        } else if op == 7 {
            let c = stack.pop().unwrap();
            if c == 0 {
                pc = PROG[pc] as usize;
            } else {
                pc += 1;
            }
        } else if op == 8 {
            pc = PROG[pc] as usize;
        } else if op == 9 {
            result = *stack.last().unwrap();
            break;
        } else {
            unreachable!();
        }
    }
    result % P
}

fn main() {
    let n: i64 = env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(800000);
    println!("{}", run(n));
    println!("vm({})", n);
}
