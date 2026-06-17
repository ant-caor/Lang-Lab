// vm: a tiny stack-based bytecode virtual machine - the control-flow / interpreter-dispatch axis.
// Executes a FIXED program (the PROG array, shared verbatim by every language) that computes
// acc = (acc*31 + i*i) mod 2^32 over i in 0..N-1 with an explicit loop. The hot path is the dispatch
// loop (fetch opcode, branch, manipulate the stack) - the very thing that makes interpreters slow.
// All VM values are 64-bit (products fit); arithmetic ops mask to 32 bits.

const val P = 1000000007L
const val MASK = 0xFFFFFFFFL

// opcodes: 0 PUSH imm, 1 LOAD slot, 2 STORE slot, 3 ADD, 4 MUL, 5 SUB, 6 LT, 7 JZ addr, 8 JMP addr, 9 HALT
val PROG = intArrayOf(0,0,2,0,0,0,2,1,1,0,1,2,6,7,37,1,1,0,31,4,1,0,1,0,4,3,2,1,1,0,0,1,3,2,0,8,8,1,1,9)

fun run(n: Int): Long {
    val stack = LongArray(64)
    var sp = 0
    val locals = longArrayOf(0L, 0L, n.toLong())
    var pc = 0
    var result = 0L
    while (true) {
        val op = PROG[pc++]
        when (op) {
            0 -> stack[sp++] = PROG[pc++].toLong()
            1 -> stack[sp++] = locals[PROG[pc++]]
            2 -> locals[PROG[pc++]] = stack[--sp]
            3 -> { val b = stack[--sp]; val a = stack[--sp]; stack[sp++] = (a + b) and MASK }
            4 -> { val b = stack[--sp]; val a = stack[--sp]; stack[sp++] = (a * b) and MASK }
            5 -> { val b = stack[--sp]; val a = stack[--sp]; stack[sp++] = (a - b) and MASK }
            6 -> { val b = stack[--sp]; val a = stack[--sp]; stack[sp++] = if (a < b) 1L else 0L }
            7 -> { val c = stack[--sp]; pc = if (c == 0L) PROG[pc] else pc + 1 }
            8 -> pc = PROG[pc]
            9 -> { result = stack[sp - 1]; break }
        }
    }
    return result
}

fun main(args: Array<String>) {
    val n = if (args.isNotEmpty()) args[0].toInt() else 800000
    println(run(n) % P)
    println("vm($n)")
}
