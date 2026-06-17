# A tiny hand-written stack-based bytecode VM - the interpreter-dispatch axis. Runs a
# FIXED 40-int program (PROG, verbatim) that computes acc = (acc*31 + i*i) mod 2^32 over
# i in 0..N-1. The dispatch loop is an explicit fetch + pattern-match over the opcodes
# (no eval / no codegen - interpreted opcode by opcode). PROG lives in a tuple for O(1)
# elem/2 fetch; the stack is a list (prepend/pop the head); locals = {i, acc, N} threaded
# through recursion. Elixir ints are arbitrary precision, so the MUL product (~2^40) is
# exact; ADD/SUB/MUL mask to 32 bits with Bitwise.band/2.
import Bitwise

defmodule VM do
  # opcodes: 0 PUSH imm, 1 LOAD slot, 2 STORE slot, 3 ADD, 4 MUL, 5 SUB, 6 LT, 7 JZ addr, 8 JMP addr, 9 HALT
  @prog {0, 0, 2, 0, 0, 0, 2, 1, 1, 0, 1, 2, 6, 7, 37, 1, 1, 0, 31, 4, 1, 0, 1, 0, 4, 3,
         2, 1, 1, 0, 0, 1, 3, 2, 0, 8, 8, 1, 1, 9}
  @mask 0xFFFFFFFF

  def run(n), do: exec([], {0, 0, n}, 0)

  # Fetch the opcode at pc, then branch to its handler - the hand-written dispatch loop.
  defp exec(stack, locals, pc) do
    op = elem(@prog, pc)
    dispatch(op, stack, locals, pc + 1)
  end

  # 0 PUSH imm: push PROG[pc]
  defp dispatch(0, stack, locals, pc),
    do: exec([elem(@prog, pc) | stack], locals, pc + 1)

  # 1 LOAD slot: push locals[PROG[pc]]
  defp dispatch(1, stack, locals, pc),
    do: exec([load(locals, elem(@prog, pc)) | stack], locals, pc + 1)

  # 2 STORE slot: locals[PROG[pc]] = pop
  defp dispatch(2, [v | stack], locals, pc),
    do: exec(stack, store(locals, elem(@prog, pc), v), pc + 1)

  # 3 ADD: b=pop; a=pop; push (a+b) & MASK
  defp dispatch(3, [b, a | stack], locals, pc),
    do: exec([band(a + b, @mask) | stack], locals, pc)

  # 4 MUL: b=pop; a=pop; push (a*b) & MASK
  defp dispatch(4, [b, a | stack], locals, pc),
    do: exec([band(a * b, @mask) | stack], locals, pc)

  # 5 SUB: b=pop; a=pop; push (a-b) & MASK
  defp dispatch(5, [b, a | stack], locals, pc),
    do: exec([band(a - b, @mask) | stack], locals, pc)

  # 6 LT: b=pop; a=pop; push (a<b)?1:0
  defp dispatch(6, [b, a | stack], locals, pc),
    do: exec([if(a < b, do: 1, else: 0) | stack], locals, pc)

  # 7 JZ addr: c=pop; if c==0: pc=PROG[pc] else pc+=1
  defp dispatch(7, [0 | stack], locals, pc),
    do: exec(stack, locals, elem(@prog, pc))

  defp dispatch(7, [_ | stack], locals, pc),
    do: exec(stack, locals, pc + 1)

  # 8 JMP addr: pc=PROG[pc]
  defp dispatch(8, stack, locals, pc),
    do: exec(stack, locals, elem(@prog, pc))

  # 9 HALT: result = top of stack
  defp dispatch(9, [result | _], _locals, _pc), do: result

  defp load({i, _a, _n}, 0), do: i
  defp load({_i, a, _n}, 1), do: a
  defp load({_i, _a, n}, 2), do: n

  defp store({_i, a, n}, 0, v), do: {v, a, n}
  defp store({i, _a, n}, 1, v), do: {i, v, n}
  defp store({i, a, _n}, 2, v), do: {i, a, v}
end

n =
  case System.argv() do
    [a | _] -> String.to_integer(a)
    _ -> 800000
  end

p = 1000000007
IO.puts(rem(VM.run(n), p))
IO.puts("vm(#{n})")
