// tak: the Takeuchi function - the function-call / recursion-overhead axis of the suite.
// Naive recursive tak(x,y,z): three recursive calls per non-base node, NO memoization, NO
// iterative rewrite. It touches no arrays and allocates nothing - the ONLY thing it stresses
// is the cost of a function call + return + a couple of integer compares/decrements. The size
// n maps to the classic shape tak(3n, 2n, n).
//
// Checksum = the TOTAL number of calls (a strict invariant of doing the identical recursion;
// evaluation is eager so all three inner calls always run). Secondary = the returned value.
// All integer; values stay tiny (no overflow).
use std::env;
use std::sync::atomic::{AtomicU64, Ordering};

// Module-level call counter (C's `static long calls`). Relaxed ordering: single-thread, we
// only need the increments to accumulate - no cross-thread synchronization is involved.
static CALLS: AtomicU64 = AtomicU64::new(0);

fn tak(x: i32, y: i32, z: i32) -> i32 {
    CALLS.fetch_add(1, Ordering::Relaxed);
    if y < x {
        tak(tak(x - 1, y, z), tak(y - 1, z, x), tak(z - 1, x, y))
    } else {
        z
    }
}

fn main() {
    let n: i32 = env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(6);
    let r = tak(3 * n, 2 * n, n);
    println!("{}", CALLS.load(Ordering::Relaxed));
    println!("tak({}) = {}", n, r);
}
