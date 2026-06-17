// bigint: hand-rolled multi-precision arithmetic - the carry-propagation axis. Compute N! as an
// array of base-2^32 limbs by repeated bignum*smallint multiplication (each limb: cur = limb*k +
// carry; store low 32 bits, propagate the high bits), then poly-hash the limbs. Implemented by hand
// (NO native/library big integers - languages with built-in bignum must hand-roll too), so it
// measures raw multi-word arithmetic. All integer-deterministic.
use std::env;

const P: u64 = 1000000007;

fn run(n: i64) -> u64 {
    let mut limbs: Vec<u32> = vec![1];
    for k in 2..=n {
        let k = k as u64;
        let mut carry: u64 = 0;
        for limb in limbs.iter_mut() {
            let cur = (*limb as u64) * k + carry;
            *limb = (cur & 0xFFFFFFFF) as u32;
            carry = cur >> 32;
        }
        while carry > 0 {
            limbs.push((carry & 0xFFFFFFFF) as u32);
            carry >>= 32;
        }
    }
    let mut h: u64 = 0;
    for &limb in limbs.iter() {
        h = (h * 31 + limb as u64) % P;
    }
    h
}

fn main() {
    let n: i64 = env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(6000);
    println!("{}", run(n));
    println!("bigint({})", n);
}
