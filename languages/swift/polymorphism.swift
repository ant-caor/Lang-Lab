import Foundation

// polymorphism: the dynamic-dispatch / virtual-call axis. Build N objects of K=6 concrete types
// in an unpredictable LCG order (megamorphic -> no devirtualization), then fold an accumulator
// through all of them M times via obj.apply(acc). Swift uses its idiomatic runtime polymorphism:
// a protocol with a method and an array of existentials, so each call is a real witness-table
// dispatch resolved at runtime. NOT a type-tag switch. Checksum = the final accumulator.

let P = 1000000007
let N = 10000
let K = 6

// The "virtual method" protocol. Each conforming type has the SAME fields but its OWN apply()
// formula; which one runs is decided at runtime by the object's dynamic type (witness table).
protocol Apply {
    func apply(_ x: Int) -> Int
}

// Six distinct per-type transforms. Distinct large multipliers so the per-pass composition never
// reaches a fixed point: acc stays chaotic and the checksum depends on M (proof all N*M ran).
// `final` so each apply() body is monomorphic, but dispatch through the [Apply] existential array
// is still a runtime protocol-witness call. Int is 64-bit; x*1000003 (< ~1e15) cannot overflow.
final class T0: Apply { let a, b, c: Int; init(_ a: Int, _ b: Int, _ c: Int) { self.a = a; self.b = b; self.c = c }
    func apply(_ x: Int) -> Int { return (x * 1000003 + a) % P } }
final class T1: Apply { let a, b, c: Int; init(_ a: Int, _ b: Int, _ c: Int) { self.a = a; self.b = b; self.c = c }
    func apply(_ x: Int) -> Int { return (x * 998273 + b) % P } }
final class T2: Apply { let a, b, c: Int; init(_ a: Int, _ b: Int, _ c: Int) { self.a = a; self.b = b; self.c = c }
    func apply(_ x: Int) -> Int { return (x * 999983 + c) % P } }
final class T3: Apply { let a, b, c: Int; init(_ a: Int, _ b: Int, _ c: Int) { self.a = a; self.b = b; self.c = c }
    func apply(_ x: Int) -> Int { return (x * 997879 + a + b) % P } }
final class T4: Apply { let a, b, c: Int; init(_ a: Int, _ b: Int, _ c: Int) { self.a = a; self.b = b; self.c = c }
    func apply(_ x: Int) -> Int { return (x * 996323 + b * c) % P } }
final class T5: Apply { let a, b, c: Int; init(_ a: Int, _ b: Int, _ c: Int) { self.a = a; self.b = b; self.c = c }
    func apply(_ x: Int) -> Int { return (x * 995369 + a + c) % P } }

// Constructor table indexed by the LCG type (the analogue of C's VT[] / Python's TYPES[]). This
// is object CONSTRUCTION, not the dispatch under test - it picks WHICH concrete type to build;
// the runtime polymorphism happens later in the fold. No type-tag switch anywhere.
let TYPES: [(Int, Int, Int) -> Apply] = [
    { T0($0, $1, $2) }, { T1($0, $1, $2) }, { T2($0, $1, $2) },
    { T3($0, $1, $2) }, { T4($0, $1, $2) }, { T5($0, $1, $2) },
]

func lcg(_ s: Int) -> Int { return (s &* 1103515245 &+ 12345) & 0x7fffffff }

let M = CommandLine.arguments.count > 1 ? (Int(CommandLine.arguments[1]) ?? 50) : 50

// Build the objects in LCG generation order (megamorphic; NOT sorted by type). Type from the
// high bits ((s >> 16) % K) since the LCG's low bits correlate; fields are s % 1000.
var objs = [Apply]()
objs.reserveCapacity(N)
var s = 42
for _ in 0..<N {
    s = lcg(s); let t = (s >> 16) % K   // type from HIGH bits; all K used -> megamorphic
    s = lcg(s); let a = s % 1000
    s = lcg(s); let b = s % 1000
    s = lcg(s); let c = s % 1000
    objs.append(TYPES[t](a, b, c))
}

// The fold: acc threads through every call (a strict data dependency), so exactly N*M dynamic
// dispatches happen. The measured hot loop below is pure runtime polymorphism - o.apply is a
// protocol-witness call resolved from each object's dynamic type, with no type tag in sight.
var acc = 1
for _ in 0..<M {
    for o in objs {
        acc = o.apply(acc)
    }
}
print(acc)
print("polymorphism(\(M))")
