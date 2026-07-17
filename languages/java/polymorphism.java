// polymorphism: the dynamic-dispatch / virtual-call-overhead axis of the suite. Build N objects of
// K=6 distinct concrete types in an unpredictable LCG order so the call site stays MEGAMORPHIC (no
// devirtualization / inline-cache wins past the typical <=4 entries), then fold an accumulator
// through all of them M times: acc = obj.apply(acc). Each type has the SAME fields but its OWN
// apply() formula; which one runs is resolved at RUNTIME from the object's type. The acc threads
// through every call (a strict data dependency), so the work cannot be hoisted or precomputed:
// exactly N*M real virtual dispatches happen. The only thing this measures is that dispatch cost.
//
// Java's idiomatic runtime polymorphism: an abstract class with an abstract method, six
// subclasses overriding it, an Apply[] of the base type, and a virtual call objs[i].apply(acc).
// NOT a source-level type tag + switch/if-chain (that would measure a branch, not a method resolution).

class Polymorphism {
    static final int N = 10000;
    static final int K = 6;

    static long lcg(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }

    static long polymorphism(int m) {
        Apply[] objs = new Apply[N];
        long s = 42L;
        for (int i = 0; i < N; i++) {
            s = lcg(s); int t = (int) ((s >> 16) % K);   // type from HIGH bits (LCG low bits correlate); all K used
            s = lcg(s); long a = s % 1000;
            s = lcg(s); long b = s % 1000;
            s = lcg(s); long c = s % 1000;
            objs[i] = switch (t) {
                case 0 -> new T0(a, b, c);
                case 1 -> new T1(a, b, c);
                case 2 -> new T2(a, b, c);
                case 3 -> new T3(a, b, c);
                case 4 -> new T4(a, b, c);
                default -> new T5(a, b, c);
            };
        }
        long acc = 1L;
        for (int pass = 0; pass < m; pass++) {
            for (int i = 0; i < N; i++) {
                acc = objs[i].apply(acc);   // DYNAMIC dispatch (virtual call per object)
            }
        }
        return acc;
    }

    public static void main(String[] args) {
        int m = args.length > 0 ? Integer.parseInt(args[0]) : 50;
        System.out.println(polymorphism(m));
        System.out.println("polymorphism(" + m + ")");
    }
}

// Six distinct per-type transforms (the "virtual method" bodies). All integer, all use x so the
// dependency chain is real; kept tiny so the DISPATCH dominates the per-call cost. Distinct large
// multipliers so the composition over a pass never reaches a fixed point: acc stays chaotic and the
// checksum depends on M (proof that all N*M dispatches ran).
abstract class Apply {
    static final long P = 1000000007L;
    final long a, b, c;
    Apply(long a, long b, long c) { this.a = a; this.b = b; this.c = c; }
    abstract long apply(long x);
}

final class T0 extends Apply {
    T0(long a, long b, long c) { super(a, b, c); }
    long apply(long x) { return (x * 1000003L + a) % P; }
}

final class T1 extends Apply {
    T1(long a, long b, long c) { super(a, b, c); }
    long apply(long x) { return (x * 998273L + b) % P; }
}

final class T2 extends Apply {
    T2(long a, long b, long c) { super(a, b, c); }
    long apply(long x) { return (x * 999983L + c) % P; }
}

final class T3 extends Apply {
    T3(long a, long b, long c) { super(a, b, c); }
    long apply(long x) { return (x * 997879L + a + b) % P; }
}

final class T4 extends Apply {
    T4(long a, long b, long c) { super(a, b, c); }
    long apply(long x) { return (x * 996323L + b * c) % P; }
}

final class T5 extends Apply {
    T5(long a, long b, long c) { super(a, b, c); }
    long apply(long x) { return (x * 995369L + a + c) % P; }
}
