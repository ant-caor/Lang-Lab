// Mandelbrot set over an N x N grid of the complex plane [-1.5, 0.5] x [-1.0, 1.0].
// A pixel is "in the set" if |z| stays <= 2 (i.e. zr^2+zi^2 <= 4) through 50 iterations
// of z := z^2 + c starting from z = 0. The checksum is the count of in-set pixels.
//
// IEEE-754 double (f64) throughout. The 2*zr*zi term is written as t+t (t = zr*zi)
// instead of 2.0*zr*zi so there is NO multiply-add pattern for a compiler to FMA-contract;
// t+t is bit-identical to 2.0*t. This keeps the result bit-exact across every language
// regardless of FMA, fast-math defaults, or auto-vectorization.
use std::env;

fn mandel(n: i32) -> i64 {
    let mut count: i64 = 0;
    for y in 0..n {
        let ci = 2.0 * y as f64 / n as f64 - 1.0;
        for x in 0..n {
            let cr = 2.0 * x as f64 / n as f64 - 1.5;
            let mut zr: f64 = 0.0;
            let mut zi: f64 = 0.0;
            let mut tr: f64 = 0.0;
            let mut ti: f64 = 0.0;
            let mut i = 0;
            while i < 50 && tr + ti <= 4.0 {
                let t = zr * zi;
                zi = t + t + ci; // == 2*zr*zi + ci, FMA-proof
                zr = tr - ti + cr;
                tr = zr * zr;
                ti = zi * zi;
                i += 1;
            }
            if tr + ti <= 4.0 {
                count += 1; // never escaped -> in set
            }
        }
    }
    count
}

fn main() {
    let n: i32 = env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(128);
    println!("{}", mandel(n));
    println!("mandelbrot({})", n);
}
