// vm: a tiny stack-based bytecode virtual machine - the control-flow / interpreter-dispatch axis.
// Executes a FIXED program (the PROG array, shared verbatim by every language) that computes
// acc = (acc*31 + i*i) mod 2^32 over i in 0..N-1 with an explicit loop. The hot path is the dispatch
// loop (fetch opcode, branch, manipulate the stack) - the very thing that makes interpreters slow.
// All VM values are 64-bit (products fit); arithmetic ops mask to 32 bits.

class Vm {
    static final long P = 1000000007L;
    static final long MASK = 0xFFFFFFFFL;

    // opcodes: 0 PUSH imm, 1 LOAD slot, 2 STORE slot, 3 ADD, 4 MUL, 5 SUB, 6 LT, 7 JZ addr, 8 JMP addr, 9 HALT
    static final int[] PROG = {0,0,2,0,0,0,2,1,1,0,1,2,6,7,37,1,1,0,31,4,1,0,1,0,4,3,2,1,1,0,0,1,3,2,0,8,8,1,1,9};

    static long run(int n) {
        long[] stack = new long[64];
        int sp = 0;
        long[] locals = {0L, 0L, (long) n};
        int pc = 0;
        while (true) {
            int op = PROG[pc++];
            switch (op) {
                case 0 -> stack[sp++] = PROG[pc++];
                case 1 -> stack[sp++] = locals[PROG[pc++]];
                case 2 -> locals[PROG[pc++]] = stack[--sp];
                case 3 -> { long b = stack[--sp]; long a = stack[--sp]; stack[sp++] = (a + b) & MASK; }
                case 4 -> { long b = stack[--sp]; long a = stack[--sp]; stack[sp++] = (a * b) & MASK; }
                case 5 -> { long b = stack[--sp]; long a = stack[--sp]; stack[sp++] = (a - b) & MASK; }
                case 6 -> { long b = stack[--sp]; long a = stack[--sp]; stack[sp++] = (a < b) ? 1L : 0L; }
                case 7 -> { long c = stack[--sp]; pc = (c == 0L) ? PROG[pc] : pc + 1; }
                case 8 -> pc = PROG[pc];
                case 9 -> { return stack[sp - 1]; }
                default -> throw new IllegalStateException("bad opcode " + op);
            }
        }
    }

    public static void main(String[] args) {
        int n = args.length > 0 ? Integer.parseInt(args[0]) : 800000;
        System.out.println(run(n) % P);
        System.out.println("vm(" + n + ")");
    }
}
