// polymorphism: the dynamic-dispatch / virtual-call-overhead axis of the suite. Build N objects
// of K=6 distinct concrete types (mixed in an unpredictable LCG order so the call site is
// MEGAMORPHIC -> no devirtualization / inline-cache wins), then fold an accumulator through all
// of them M times: acc = obj.apply(acc). Each type has the SAME fields but its OWN apply()
// formula; which one runs is resolved at RUNTIME from per-object data. The acc threads through
// every call (a strict data dependency), so the work cannot be hoisted or precomputed: exactly
// N*M real dispatches happen. The only thing this measures is the cost of that runtime dispatch.
//
// C has no OOP, so its idiomatic equivalent of a vtable is a FUNCTION POINTER stored per object
// (an indirect call resolved by the object's runtime data) - the documented C/COBOL asymmetry,
// the fair analogue of a virtual/interface/duck-typed method call. NOT a source-level type switch.
// All integer; checksum = the final accumulator. K=6 (> a typical polymorphic-inline-cache).
#include <stdio.h>
#include <stdlib.h>

#define P 1000000007L
#define N 10000
#define K 6

typedef struct Obj Obj;
struct Obj { long (*apply)(Obj *, long); long a, b, c; };

// Six distinct per-type transforms (the "virtual method" bodies). All integer, all use x so the
// dependency chain is real; kept tiny so the DISPATCH dominates the per-call cost.
// Distinct large multipliers so the composition over a pass does NOT reach a fixed point: acc
// stays chaotic and the checksum depends on M (proof that all N*M dispatches ran).
static long apply0(Obj *o, long x) { return (x * 1000003L + o->a) % P; }
static long apply1(Obj *o, long x) { return (x * 998273L + o->b) % P; }
static long apply2(Obj *o, long x) { return (x * 999983L + o->c) % P; }
static long apply3(Obj *o, long x) { return (x * 997879L + o->a + o->b) % P; }
static long apply4(Obj *o, long x) { return (x * 996323L + o->b * o->c) % P; }
static long apply5(Obj *o, long x) { return (x * 995369L + o->a + o->c) % P; }

static long (*VT[K])(Obj *, long) = { apply0, apply1, apply2, apply3, apply4, apply5 };

static long lcg(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }

int main(int argc, char **argv) {
    int M = argc > 1 ? atoi(argv[1]) : 50;
    Obj *objs = malloc(N * sizeof(Obj));
    long s = 42;
    for (int i = 0; i < N; i++) {
        s = lcg(s); objs[i].apply = VT[(s >> 16) % K];   // type from HIGH bits (LCG low bits are
                                                          // correlated); all K used -> megamorphic
        s = lcg(s); objs[i].a = s % 1000;
        s = lcg(s); objs[i].b = s % 1000;
        s = lcg(s); objs[i].c = s % 1000;
    }
    long acc = 1;
    for (int pass = 0; pass < M; pass++)
        for (int i = 0; i < N; i++)
            acc = objs[i].apply(&objs[i], acc);   // DYNAMIC dispatch (indirect call per object)
    printf("%ld\n", acc);
    printf("polymorphism(%d)\n", M);
    free(objs);
    return 0;
}
