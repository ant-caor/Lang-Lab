// k-nucleotide: count the frequency of every length-K substring (k-mer) of a
// deterministically generated DNA sequence, using a hash map, then reduce the map to
// one order-independent checksum.
//
// This is the associative-container axis of the suite. Rust uses its idiomatic built-in
// std::collections::HashMap keyed by the k-mer string (the K-byte substring) - a real
// hash map, NOT direct-addressing on the small key space (which would be an unfair
// shortcut).
//
// Everything is integer-deterministic (no floating point): the sequence comes from an
// integer LCG, and the checksum is sum over map entries of encode(kmer)*count mod P,
// which is independent of the map's hash function and iteration order.
use std::collections::HashMap;
use std::env;

const K: usize = 8;
const P: i64 = 1000000007;
const IM: i64 = 139968;
const IA: i64 = 3877;
const IC: i64 = 29573;

fn gen(l: usize) -> Vec<u8> {
    let mut s = Vec::with_capacity(l);
    let mut seed: i64 = 42;
    for _ in 0..l {
        seed = (seed * IA + IC) % IM;
        let c = if seed < 42000 {
            b'A'
        } else if seed < 70000 {
            b'C'
        } else if seed < 98000 {
            b'G'
        } else {
            b'T'
        };
        s.push(c);
    }
    s
}

fn run(l: usize) -> i64 {
    let s = gen(l);

    let mut map: HashMap<[u8; K], i64> = HashMap::new();
    if l >= K {
        for i in 0..=(l - K) {
            let mut kmer = [0u8; K];
            kmer.copy_from_slice(&s[i..i + K]);
            *map.entry(kmer).or_insert(0) += 1;
        }
    }

    let mut acc: i64 = 0;
    for (kmer, &count) in &map {
        let mut e: i64 = 0;
        for &c in kmer {
            let code = match c {
                b'A' => 0,
                b'C' => 1,
                b'G' => 2,
                _ => 3,
            };
            e = e * 4 + code;
        }
        acc = (acc + e * count) % P;
    }
    acc
}

fn main() {
    let l: usize = env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(100000);
    println!("{}", run(l));
    println!("k-nucleotide({})", l);
}
