// polymorphism: the dynamic-dispatch / virtual-call-overhead axis of the suite. Build N objects
// of K=6 distinct concrete types (mixed in an unpredictable LCG order so the call site is
// MEGAMORPHIC -> no devirtualization / inline-cache wins), then fold an accumulator through all
// of them M times: acc = obj.Apply(acc). Each type has the SAME fields but its OWN Apply()
// formula; which one runs is resolved at RUNTIME by the CLR's virtual dispatch on the object's
// concrete type. The acc threads through every call (a strict data dependency), so the work
// cannot be hoisted or precomputed: exactly N*M real dispatches happen.
//
// C# uses its idiomatic runtime polymorphism: an abstract base class with six subclasses and an
// array of the base type. Dispatch is a genuine virtual call (vtable lookup), NOT a type tag +
// switch (which the fairness rules forbid). All integer; checksum = the final accumulator.
using System;

// Distinct large multipliers so the per-pass composition never reaches a fixed point: acc stays
// chaotic and the checksum depends on M (proof all N*M dispatches ran). Tiny bodies so the
// DISPATCH dominates the per-call cost.
abstract class Apply
{
    public long a, b, c;
    public abstract long Run(long x);
}

class T0 : Apply { public override long Run(long x) => (x * 1000003L + a) % Polymorphism.P; }
class T1 : Apply { public override long Run(long x) => (x * 998273L + b) % Polymorphism.P; }
class T2 : Apply { public override long Run(long x) => (x * 999983L + c) % Polymorphism.P; }
class T3 : Apply { public override long Run(long x) => (x * 997879L + a + b) % Polymorphism.P; }
class T4 : Apply { public override long Run(long x) => (x * 996323L + b * c) % Polymorphism.P; }
class T5 : Apply { public override long Run(long x) => (x * 995369L + a + c) % Polymorphism.P; }

class Polymorphism
{
    public const long P = 1000000007L;
    const int N = 10000;
    const int K = 6;

    // glibc-style LCG; the & masks to a non-negative 31-bit value so the C `long` arithmetic
    // (s*1103515245 fits in 64 bits) matches exactly.
    static long Lcg(long s) => (s * 1103515245L + 12345L) & 0x7fffffffL;

    static Apply Make(long t, long a, long b, long c)
    {
        Apply o;
        switch (t)   // construction-time factory, NOT the dispatch path (the fold below is virtual)
        {
            case 0: o = new T0(); break;
            case 1: o = new T1(); break;
            case 2: o = new T2(); break;
            case 3: o = new T3(); break;
            case 4: o = new T4(); break;
            default: o = new T5(); break;
        }
        o.a = a; o.b = b; o.c = c;
        return o;
    }

    static void Main(string[] args)
    {
        int m = args.Length > 0 ? int.Parse(args[0]) : 50;
        var objs = new Apply[N];
        long s = 42;
        for (int i = 0; i < N; i++)
        {
            s = Lcg(s); long t = (s >> 16) % K;   // type from HIGH bits (LCG low bits correlate)
            s = Lcg(s); long a = s % 1000;
            s = Lcg(s); long b = s % 1000;
            s = Lcg(s); long c = s % 1000;
            objs[i] = Make(t, a, b, c);
        }
        long acc = 1;
        for (int pass = 0; pass < m; pass++)
            for (int i = 0; i < N; i++)
                acc = objs[i].Run(acc);   // DYNAMIC dispatch (virtual call per object)
        Console.WriteLine(acc);
        Console.WriteLine($"polymorphism({m})");
    }
}
