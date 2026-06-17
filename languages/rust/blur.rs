// blur: a 2D image-convolution benchmark - the stencil axis of the suite. Generate a
// grayscale N x N image, then apply a 3x3 Gaussian blur kernel [1 2 1; 2 4 2; 1 2 1]/16
// PASSES times (double-buffered), with clamp (edge-replication) border handling, and reduce
// the result to a polynomial hash. All integer arithmetic - deterministic, no floating point.
use std::env;

const P: i64 = 1000000007;
const PASSES: i32 = 4;

fn lcg(s: i64) -> i64 {
    (s.wrapping_mul(1103515245).wrapping_add(12345)) & 0x7fffffff
}

fn clampi(x: i32, n: i32) -> i32 {
    if x < 0 { 0 } else if x >= n { n - 1 } else { x }
}

fn run(n: i32) -> i64 {
    const K: [i32; 9] = [1, 2, 1, 2, 4, 2, 1, 2, 1]; // 3x3, sum 16
    let nn = (n as usize) * (n as usize);
    let mut src = vec![0i32; nn];
    let mut dst = vec![0i32; nn];

    let mut s: i64 = 42;
    for k in 0..nn {
        s = lcg(s);
        src[k] = (s % 256) as i32;
    }

    for _pass in 0..PASSES {
        for i in 0..n {
            for j in 0..n {
                let mut acc: i32 = 0;
                for di in -1..=1 {
                    let ni = clampi(i + di, n);
                    for dj in -1..=1 {
                        let nj = clampi(j + dj, n);
                        acc += K[((di + 1) * 3 + (dj + 1)) as usize]
                            * src[(ni as usize) * (n as usize) + nj as usize];
                    }
                }
                dst[(i as usize) * (n as usize) + j as usize] = acc / 16; // integer division
            }
        }
        std::mem::swap(&mut src, &mut dst); // double-buffer swap
    }

    let mut h: i64 = 0;
    for k in 0..nn {
        h = (h * 31 + src[k] as i64) % P;
    }
    h
}

fn main() {
    let n: i32 = env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(256);
    println!("{}", run(n));
    println!("blur({})", n);
}
