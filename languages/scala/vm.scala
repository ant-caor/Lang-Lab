// vm: a tiny stack-based bytecode virtual machine - the control-flow / interpreter-dispatch axis.
// Executes a FIXED program (the PROG array, shared verbatim by every language) that computes
// acc = (acc*31 + i*i) mod 2^32 over i in 0..N-1 with an explicit loop. The hot path is the dispatch
// loop (fetch opcode, branch, manipulate the stack) - the very thing that makes interpreters slow.
// Hand-written dispatch (a while loop + match over opcodes; no eval, no codegen). VM values are
// 64-bit Long (the MUL product reaches ~2^40 before masking); ADD/SUB/MUL mask to 32 bits.
object Vm {
  final val P = 1000000007L
  final val MASK = 0xFFFFFFFFL

  // opcodes: 0 PUSH imm, 1 LOAD slot, 2 STORE slot, 3 ADD, 4 MUL, 5 SUB, 6 LT, 7 JZ addr, 8 JMP addr, 9 HALT
  val PROG: Array[Int] = Array(
    0, 0, 2, 0, 0, 0, 2, 1, 1, 0, 1, 2, 6, 7, 37, 1, 1, 0, 31, 4,
    1, 0, 1, 0, 4, 3, 2, 1, 1, 0, 0, 1, 3, 2, 0, 8, 8, 1, 1, 9)

  def run(n: Int): Long = {
    val stack = new Array[Long](64) // 64-bit VM values
    var sp = 0
    val locals = Array(0L, 0L, n.toLong) // [i, acc, N]
    var pc = 0
    var result = 0L
    var running = true
    while (running) {
      val op = PROG(pc); pc += 1
      op match {
        case 0 => stack(sp) = PROG(pc).toLong; sp += 1; pc += 1               // PUSH imm
        case 1 => stack(sp) = locals(PROG(pc)); sp += 1; pc += 1              // LOAD slot
        case 2 => sp -= 1; locals(PROG(pc)) = stack(sp); pc += 1              // STORE slot
        case 3 => val b = stack(sp - 1); val a = stack(sp - 2); sp -= 1; stack(sp - 1) = (a + b) & MASK // ADD
        case 4 => val b = stack(sp - 1); val a = stack(sp - 2); sp -= 1; stack(sp - 1) = (a * b) & MASK // MUL
        case 5 => val b = stack(sp - 1); val a = stack(sp - 2); sp -= 1; stack(sp - 1) = (a - b) & MASK // SUB
        case 6 => val b = stack(sp - 1); val a = stack(sp - 2); sp -= 1; stack(sp - 1) = if (a < b) 1L else 0L // LT
        case 7 => sp -= 1; if (stack(sp) == 0L) pc = PROG(pc) else pc += 1    // JZ addr
        case 8 => pc = PROG(pc)                                               // JMP addr
        case 9 => result = stack(sp - 1); running = false                    // HALT
      }
    }
    result
  }

  def main(args: Array[String]): Unit = {
    val n = if (args.nonEmpty) args(0).toInt else 800000
    println(run(n) % P)
    println(s"vm($n)")
  }
}
