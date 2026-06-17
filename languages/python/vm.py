# vm: a tiny stack-based bytecode virtual machine - the control-flow / interpreter-dispatch axis.
# Executes a FIXED program (the PROG array, shared verbatim by every language) that computes
# acc = (acc*31 + i*i) mod 2^32 over i in 0..N-1 with an explicit loop. The hot path is the dispatch
# loop (fetch opcode, branch, manipulate the stack) - the very thing that makes interpreters slow.
# Python ints are unbounded; ADD/SUB/MUL mask to 32 bits, so values stay within VM semantics.
import sys

P = 1000000007
MASK = 0xFFFFFFFF

# opcodes: 0 PUSH imm, 1 LOAD slot, 2 STORE slot, 3 ADD, 4 MUL, 5 SUB, 6 LT, 7 JZ addr, 8 JMP addr, 9 HALT
PROG = [0, 0, 2, 0, 0, 0, 2, 1, 1, 0, 1, 2, 6, 7, 37, 1, 1, 0, 31, 4,
        1, 0, 1, 0, 4, 3, 2, 1, 1, 0, 0, 1, 3, 2, 0, 8, 8, 1, 1, 9]


def run(n):
    stack = []
    locals_ = [0, 0, n]  # [i, acc, N]
    pc = 0
    result = 0
    while True:
        op = PROG[pc]
        pc += 1
        if op == 0:  # PUSH imm
            stack.append(PROG[pc])
            pc += 1
        elif op == 1:  # LOAD slot
            stack.append(locals_[PROG[pc]])
            pc += 1
        elif op == 2:  # STORE slot
            locals_[PROG[pc]] = stack.pop()
            pc += 1
        elif op == 3:  # ADD
            b = stack.pop()
            a = stack.pop()
            stack.append((a + b) & MASK)
        elif op == 4:  # MUL
            b = stack.pop()
            a = stack.pop()
            stack.append((a * b) & MASK)
        elif op == 5:  # SUB
            b = stack.pop()
            a = stack.pop()
            stack.append((a - b) & MASK)
        elif op == 6:  # LT
            b = stack.pop()
            a = stack.pop()
            stack.append(1 if a < b else 0)
        elif op == 7:  # JZ addr
            c = stack.pop()
            if c == 0:
                pc = PROG[pc]
            else:
                pc += 1
        elif op == 8:  # JMP addr
            pc = PROG[pc]
        elif op == 9:  # HALT
            result = stack[-1]
            break
    return result


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 800000
    print(run(n) % P)
    print("vm(%d)" % n)
