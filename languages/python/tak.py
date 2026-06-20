import sys

# tak: Takeuchi function - the function-call / recursion-overhead axis. Naive triple recursion,
# no memoization, no iterative rewrite. Checksum = total number of calls (identical-recursion
# invariant); secondary = the returned value. Size n -> tak(3n, 2n, n). Pure integer, no memory.
sys.setrecursionlimit(1_000_000)

calls = 0


def tak(x, y, z):
    global calls
    calls += 1
    if y < x:
        return tak(tak(x - 1, y, z), tak(y - 1, z, x), tak(z - 1, x, y))
    return z


n = int(sys.argv[1]) if len(sys.argv) > 1 else 6
r = tak(3 * n, 2 * n, n)
print(calls)
print(f"tak({n}) = {r}")
