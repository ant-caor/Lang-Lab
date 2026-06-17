// reverse-complement: generate a DNA sequence, reverse it in place while complementing
// each base (A<->T, C<->G), then reduce it to a polynomial string hash. The reverse uses a
// hand-written two-pointer loop (NOT a stdlib bulk reverse) and the hash a per-character
// loop (NOT a builtin), so this measures the language's own per-character processing -
// consistent with the suite's no-stdlib-shortcut rule. Everything is integer-deterministic.
use std::env;

const P: i64 = 1000000007;
const IM: i64 = 139968;
const IA: i64 = 3877;
const IC: i64 = 29573;

fn comp(c: u8) -> u8 {
    // A<->T, C<->G; only A/C/G/T occur
    if c == b'A' {
        b'T'
    } else if c == b'C' {
        b'G'
    } else if c == b'G' {
        b'C'
    } else {
        b'A'
    }
}

fn run(l: usize) -> i64 {
    let mut s: Vec<u8> = vec![0u8; l];
    let mut seed: i64 = 42;
    for i in 0..l {
        seed = (seed * IA + IC) % IM;
        s[i] = if seed < 42000 {
            b'A'
        } else if seed < 70000 {
            b'C'
        } else if seed < 98000 {
            b'G'
        } else {
            b'T'
        };
    }

    // two-pointer reverse-and-complement, in place
    let mut i: usize = 0;
    if l > 0 {
        let mut j: usize = l - 1;
        while i < j {
            let a = comp(s[i]);
            s[i] = comp(s[j]);
            s[j] = a;
            i += 1;
            j -= 1;
        }
        if i == j {
            s[i] = comp(s[i]); // middle char when L is odd
        }
    }

    // polynomial string hash over the ASCII byte values (A=65, C=67, G=71, T=84)
    let mut h: i64 = 0;
    for k in 0..l {
        h = (h * 31 + s[k] as i64) % P;
    }
    h
}

fn main() {
    let l: usize = env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(100000);
    println!("{}", run(l));
    println!("reverse-complement({})", l);
}
