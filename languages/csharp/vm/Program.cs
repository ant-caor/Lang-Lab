// vm: a tiny stack-based bytecode virtual machine - the control-flow / interpreter-dispatch axis.
// Executes a FIXED program (the PROG array, shared verbatim by every language) that computes
// acc = (acc*31 + i*i) mod 2^32 over i in 0..N-1 with an explicit loop. The hot path is the dispatch
// loop (fetch opcode, branch, manipulate the stack) - the very thing that makes interpreters slow.
// All VM values are 64-bit (products fit); arithmetic ops mask to 32 bits.
using System;

class Vm
{
    const long P = 1000000007L;
    const long MASK = 0xFFFFFFFFL;

    // opcodes: 0 PUSH imm, 1 LOAD slot, 2 STORE slot, 3 ADD, 4 MUL, 5 SUB, 6 LT, 7 JZ addr, 8 JMP addr, 9 HALT
    static readonly long[] PROG = { 0,0,2,0,0,0,2,1,1,0,1,2,6,7,37,1,1,0,31,4,1,0,1,0,4,3,2,1,1,0,0,1,3,2,0,8,8,1,1,9 };

    static long Run(int n)
    {
        long[] stack = new long[64];
        int sp = 0;
        long[] locals = { 0, 0, n };
        int pc = 0;
        long result = 0;
        for (;;)
        {
            long op = PROG[pc++];
            if (op == 0) stack[sp++] = PROG[pc++];
            else if (op == 1) stack[sp++] = locals[PROG[pc++]];
            else if (op == 2) locals[PROG[pc++]] = stack[--sp];
            else if (op == 3) { long b = stack[--sp], a = stack[--sp]; stack[sp++] = (a + b) & MASK; }
            else if (op == 4) { long b = stack[--sp], a = stack[--sp]; stack[sp++] = (a * b) & MASK; }
            else if (op == 5) { long b = stack[--sp], a = stack[--sp]; stack[sp++] = (a - b) & MASK; }
            else if (op == 6) { long b = stack[--sp], a = stack[--sp]; stack[sp++] = (a < b) ? 1 : 0; }
            else if (op == 7) { long c = stack[--sp]; if (c == 0) pc = (int)PROG[pc]; else pc++; }
            else if (op == 8) pc = (int)PROG[pc];
            else if (op == 9) { result = stack[sp - 1]; break; }
        }
        return result % P;
    }

    static void Main(string[] args)
    {
        int n = args.Length > 0 ? int.Parse(args[0]) : 800000;
        Console.WriteLine(Run(n));
        Console.WriteLine($"vm({n})");
    }
}
