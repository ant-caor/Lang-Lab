import sys

# polymorphism: dynamic-dispatch / virtual-call-overhead axis. N objects of K=6 concrete types in
# an unpredictable (megamorphic) order; fold acc through all of them M times via obj.apply(acc).
# Each type has its own apply() formula; the acc threads through every call so nothing can be
# hoisted (exactly N*M real dispatches). Python uses idiomatic duck-typed method dispatch.
# Checksum = the final accumulator. All integer.
P = 1000000007
N = 10000
K = 6


# Distinct large multipliers so the per-pass composition never reaches a fixed point: acc stays
# chaotic and the checksum depends on M (proof all N*M dispatches ran).
class T0:
    __slots__ = ("a", "b", "c")
    def __init__(s, a, b, c): s.a, s.b, s.c = a, b, c
    def apply(s, x): return (x * 1000003 + s.a) % P


class T1(T0):
    def apply(s, x): return (x * 998273 + s.b) % P


class T2(T0):
    def apply(s, x): return (x * 999983 + s.c) % P


class T3(T0):
    def apply(s, x): return (x * 997879 + s.a + s.b) % P


class T4(T0):
    def apply(s, x): return (x * 996323 + s.b * s.c) % P


class T5(T0):
    def apply(s, x): return (x * 995369 + s.a + s.c) % P


TYPES = [T0, T1, T2, T3, T4, T5]


def lcg(s): return (s * 1103515245 + 12345) & 0x7fffffff


M = int(sys.argv[1]) if len(sys.argv) > 1 else 50
s = 42
objs = []
for i in range(N):
    s = lcg(s); t = (s >> 16) % K   # type from HIGH bits (LCG low bits correlate); all K used
    s = lcg(s); a = s % 1000
    s = lcg(s); b = s % 1000
    s = lcg(s); c = s % 1000
    objs.append(TYPES[t](a, b, c))
acc = 1
for _ in range(M):
    for o in objs:
        acc = o.apply(acc)
print(acc)
print(f"polymorphism({M})")
