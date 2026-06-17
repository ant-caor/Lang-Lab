// vm: a tiny stack-based bytecode virtual machine - the control-flow / interpreter-dispatch axis.
// Executes a FIXED program (the PROG array, shared verbatim by every language) that computes
// acc = (acc*31 + i*i) mod 2^32 over i in 0..N-1 with an explicit loop. The hot path is the dispatch
// loop (fetch opcode, branch, manipulate the stack) - the very thing that makes interpreters slow.
// All VM values are 64-bit (products fit); arithmetic ops mask to 32 bits.
package main

import (
	"fmt"
	"os"
	"strconv"
)

const (
	P    = 1000000007
	MASK = 0xFFFFFFFF
)

// opcodes: 0 PUSH imm, 1 LOAD slot, 2 STORE slot, 3 ADD, 4 MUL, 5 SUB, 6 LT, 7 JZ addr, 8 JMP addr, 9 HALT
var PROG = [40]int64{0, 0, 2, 0, 0, 0, 2, 1, 1, 0, 1, 2, 6, 7, 37, 1, 1, 0, 31, 4, 1, 0, 1, 0, 4, 3, 2, 1, 1, 0, 0, 1, 3, 2, 0, 8, 8, 1, 1, 9}

func run(n int) int64 {
	var stack [64]int64
	sp := 0
	locals := [3]int64{0, 0, int64(n)}
	pc := 0
	var result int64
	for {
		op := PROG[pc]
		pc++
		if op == 0 { // PUSH
			stack[sp] = PROG[pc]
			sp++
			pc++
		} else if op == 1 { // LOAD
			stack[sp] = locals[PROG[pc]]
			sp++
			pc++
		} else if op == 2 { // STORE
			sp--
			locals[PROG[pc]] = stack[sp]
			pc++
		} else if op == 3 { // ADD
			sp--
			b := stack[sp]
			sp--
			a := stack[sp]
			stack[sp] = (a + b) & MASK
			sp++
		} else if op == 4 { // MUL
			sp--
			b := stack[sp]
			sp--
			a := stack[sp]
			stack[sp] = (a * b) & MASK
			sp++
		} else if op == 5 { // SUB
			sp--
			b := stack[sp]
			sp--
			a := stack[sp]
			stack[sp] = (a - b) & MASK
			sp++
		} else if op == 6 { // LT
			sp--
			b := stack[sp]
			sp--
			a := stack[sp]
			if a < b {
				stack[sp] = 1
			} else {
				stack[sp] = 0
			}
			sp++
		} else if op == 7 { // JZ
			sp--
			c := stack[sp]
			if c == 0 {
				pc = int(PROG[pc])
			} else {
				pc++
			}
		} else if op == 8 { // JMP
			pc = int(PROG[pc])
		} else if op == 9 { // HALT
			result = stack[sp-1]
			break
		}
	}
	return result % P
}

func main() {
	n := 800000
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil {
			n = v
		}
	}
	fmt.Println(run(n))
	fmt.Printf("vm(%d)\n", n)
}
