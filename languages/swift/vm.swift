// vm: a tiny stack-based bytecode virtual machine - the control-flow / interpreter-dispatch axis.
// Executes a FIXED program (the PROG array, shared verbatim by every language) that computes
// acc = (acc*31 + i*i) mod 2^32 over i in 0..N-1 with an explicit loop. The hot path is the dispatch
// loop (fetch opcode, branch, manipulate the stack) - the very thing that makes interpreters slow.
// All VM values are 64-bit (Swift's Int is i64 here; products fit); arithmetic ops mask to 32 bits.
import Foundation

let P = 1000000007
let MASK = 0xFFFFFFFF
// opcodes: 0 PUSH imm, 1 LOAD slot, 2 STORE slot, 3 ADD, 4 MUL, 5 SUB, 6 LT, 7 JZ addr, 8 JMP addr, 9 HALT
let PROG: [Int] = [0,0,2,0,0,0,2,1,1,0,1,2,6,7,37,1,1,0,31,4,1,0,1,0,4,3,2,1,1,0,0,1,3,2,0,8,8,1,1,9]

func run(_ n: Int) -> Int {
    var stack = [Int](repeating: 0, count: 64)
    var sp = 0
    var locals = [0, 0, n]   // locals = [i, acc, N]
    var pc = 0
    var result = 0
    loop: while true {
        let op = PROG[pc]; pc += 1
        switch op {
        case 0:  // PUSH imm
            stack[sp] = PROG[pc]; sp += 1; pc += 1
        case 1:  // LOAD slot
            stack[sp] = locals[PROG[pc]]; sp += 1; pc += 1
        case 2:  // STORE slot
            sp -= 1; locals[PROG[pc]] = stack[sp]; pc += 1
        case 3:  // ADD
            let b = stack[sp - 1]; let a = stack[sp - 2]; sp -= 1
            stack[sp - 1] = (a + b) & MASK
        case 4:  // MUL
            let b = stack[sp - 1]; let a = stack[sp - 2]; sp -= 1
            stack[sp - 1] = (a * b) & MASK
        case 5:  // SUB
            let b = stack[sp - 1]; let a = stack[sp - 2]; sp -= 1
            stack[sp - 1] = (a - b) & MASK
        case 6:  // LT
            let b = stack[sp - 1]; let a = stack[sp - 2]; sp -= 1
            stack[sp - 1] = a < b ? 1 : 0
        case 7:  // JZ addr
            sp -= 1; let c = stack[sp]
            if c == 0 { pc = PROG[pc] } else { pc += 1 }
        case 8:  // JMP addr
            pc = PROG[pc]
        case 9:  // HALT
            result = stack[sp - 1]; break loop
        default:
            break loop
        }
    }
    return result
}

let n = CommandLine.arguments.count > 1 ? (Int(CommandLine.arguments[1]) ?? 800000) : 800000
print(run(n) % P)
print("vm(\(n))")
