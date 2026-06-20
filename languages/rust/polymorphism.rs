// polymorphism: the dynamic-dispatch / virtual-call-overhead axis. Build N objects of K=6 distinct
// concrete types, mixed in an unpredictable LCG order so the call site is MEGAMORPHIC (K=6 > a
// typical polymorphic inline cache -> no devirtualization). Then fold an accumulator through all of
// them M times: acc = obj.apply(acc). Each type has the SAME fields a,b,c but its OWN apply()
// formula, resolved at RUNTIME from the object's type. acc threads through every call (a strict data
// dependency) and the multipliers are large+distinct, so the per-pass map never reaches a fixed
// point: exactly N*M real dispatches happen and the checksum depends on M.
//
// Rust's idiomatic runtime polymorphism is the TRAIT OBJECT: a `dyn Apply` behind a `Box` carries a
// vtable, and `objs[i].apply(acc)` is a dynamic (indirect) call through that vtable. NOT an
// enum+match (that would be a source-level type tag + branch, which the README forbids).
//
// Every type stores all three fields a,b,c but each apply() reads only a subset (e.g. T0 ignores
// b,c) - faithful to the C/Python references, where each transform uses a different subset. The
// unused fields are intentional, so silence the dead_code warning rather than dropping the field.
#![allow(dead_code)]

use std::env;

const P: i64 = 1000000007;
const N: usize = 10000;
const K: i64 = 6;

// The "virtual method" interface. Six concrete structs implement it; the object stores its type only
// implicitly, in the vtable of the `dyn Apply` it is boxed behind.
trait Apply {
    fn apply(&self, x: i64) -> i64;
}

// All six types share the same three integer fields; only the apply() body differs. The fields are
// duplicated per struct (rather than composed) so each is a genuinely distinct concrete type with
// its own vtable -> the call site sees six targets and stays megamorphic.
struct T0 {
    a: i64,
    b: i64,
    c: i64,
}
struct T1 {
    a: i64,
    b: i64,
    c: i64,
}
struct T2 {
    a: i64,
    b: i64,
    c: i64,
}
struct T3 {
    a: i64,
    b: i64,
    c: i64,
}
struct T4 {
    a: i64,
    b: i64,
    c: i64,
}
struct T5 {
    a: i64,
    b: i64,
    c: i64,
}

// Six distinct per-type transforms (the "virtual method" bodies), each mod P. Distinct large
// multipliers keep acc chaotic so the composition never reaches a fixed point. The products fit in
// i64 (x < P < 2^30, mult < 2^20 -> x*mult < 2^50; b*c < 10^6), but use wrapping_* to make the
// intent explicit and match the suite's LCG style.
impl Apply for T0 {
    fn apply(&self, x: i64) -> i64 {
        (x.wrapping_mul(1000003).wrapping_add(self.a)) % P
    }
}
impl Apply for T1 {
    fn apply(&self, x: i64) -> i64 {
        (x.wrapping_mul(998273).wrapping_add(self.b)) % P
    }
}
impl Apply for T2 {
    fn apply(&self, x: i64) -> i64 {
        (x.wrapping_mul(999983).wrapping_add(self.c)) % P
    }
}
impl Apply for T3 {
    fn apply(&self, x: i64) -> i64 {
        (x.wrapping_mul(997879).wrapping_add(self.a).wrapping_add(self.b)) % P
    }
}
impl Apply for T4 {
    fn apply(&self, x: i64) -> i64 {
        (x.wrapping_mul(996323).wrapping_add(self.b.wrapping_mul(self.c))) % P
    }
}
impl Apply for T5 {
    fn apply(&self, x: i64) -> i64 {
        (x.wrapping_mul(995369).wrapping_add(self.a).wrapping_add(self.c)) % P
    }
}

fn lcg(s: i64) -> i64 {
    (s.wrapping_mul(1103515245).wrapping_add(12345)) & 0x7fffffff
}

fn main() {
    let m: i64 = env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(50);

    let mut objs: Vec<Box<dyn Apply>> = Vec::with_capacity(N);
    let mut s: i64 = 42;
    for _ in 0..N {
        s = lcg(s);
        let t = (s >> 16) % K; // type from HIGH bits (LCG low bits correlate); all K used
        s = lcg(s);
        let a = s % 1000;
        s = lcg(s);
        let b = s % 1000;
        s = lcg(s);
        let c = s % 1000;
        // Construct the concrete type chosen at runtime, erased to `dyn Apply` (its vtable is the
        // object's runtime type). Objects stay in LCG generation order -> megamorphic.
        let obj: Box<dyn Apply> = match t {
            0 => Box::new(T0 { a, b, c }),
            1 => Box::new(T1 { a, b, c }),
            2 => Box::new(T2 { a, b, c }),
            3 => Box::new(T3 { a, b, c }),
            4 => Box::new(T4 { a, b, c }),
            _ => Box::new(T5 { a, b, c }),
        };
        objs.push(obj);
    }

    let mut acc: i64 = 1;
    for _ in 0..m {
        for obj in &objs {
            acc = obj.apply(acc); // DYNAMIC dispatch (indirect call through the trait-object vtable)
        }
    }

    println!("{}", acc);
    println!("polymorphism({})", m);
}
