"use strict";

// vm: a tiny stack-based bytecode virtual machine - the control-flow / interpreter-dispatch
// axis. Executes a FIXED program (the PROG array, shared verbatim by every language) that
// computes acc = (acc*31 + i*i) mod 2^32 over i in 0..N-1 with an explicit loop.
// ADD/SUB/MUL operands and the MUL product stay well below 2^53 for this PROG (i*i tops
// out around 2^40), so plain Number arithmetic is exact; `>>> 0` gives the correct
// non-negative mod-2^32 wraparound (equivalent to Python's `& 0xFFFFFFFF`).

const P = 1000000007;

// opcodes: 0 PUSH imm, 1 LOAD slot, 2 STORE slot, 3 ADD, 4 MUL, 5 SUB, 6 LT, 7 JZ addr, 8 JMP addr, 9 HALT
const PROG = [
  0, 0, 2, 0, 0, 0, 2, 1, 1, 0, 1, 2, 6, 7, 37, 1, 1, 0, 31, 4,
  1, 0, 1, 0, 4, 3, 2, 1, 1, 0, 0, 1, 3, 2, 0, 8, 8, 1, 1, 9,
];

function run(n) {
  const stack = [];
  const locals = [0, 0, n]; // [i, acc, N]
  let pc = 0;
  let result = 0;
  for (;;) {
    const op = PROG[pc];
    pc += 1;
    if (op === 0) {
      // PUSH imm
      stack.push(PROG[pc]);
      pc += 1;
    } else if (op === 1) {
      // LOAD slot
      stack.push(locals[PROG[pc]]);
      pc += 1;
    } else if (op === 2) {
      // STORE slot
      locals[PROG[pc]] = stack.pop();
      pc += 1;
    } else if (op === 3) {
      // ADD
      const b = stack.pop();
      const a = stack.pop();
      stack.push((a + b) >>> 0);
    } else if (op === 4) {
      // MUL
      const b = stack.pop();
      const a = stack.pop();
      stack.push((a * b) >>> 0);
    } else if (op === 5) {
      // SUB
      const b = stack.pop();
      const a = stack.pop();
      stack.push((a - b) >>> 0);
    } else if (op === 6) {
      // LT
      const b = stack.pop();
      const a = stack.pop();
      stack.push(a < b ? 1 : 0);
    } else if (op === 7) {
      // JZ addr
      const c = stack.pop();
      if (c === 0) pc = PROG[pc];
      else pc += 1;
    } else if (op === 8) {
      // JMP addr
      pc = PROG[pc];
    } else if (op === 9) {
      // HALT
      result = stack[stack.length - 1];
      break;
    }
  }
  return result;
}

function main() {
  const n = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : 800000;
  console.log(run(n) % P);
  console.log(`vm(${n})`);
}

main();
