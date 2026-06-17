// sha256: iterated SHA-256 - the bit-manipulation / cryptography axis of the suite. Start from
// a 32-byte LCG-generated digest and apply real FIPS 180-4 SHA-256 to it N times (each hash is a
// single padded block). The hot path is rotations, XOR, shifts and modular 2^32 addition - work
// no other benchmark does. Hand-written (no crypto library); the checksum is a poly-hash of the
// final 32-byte digest. All integer; the 32-bit wraparound is explicit (u32 + wrapping_add).
use std::env;

const P: i64 = 1000000007;

const K: [u32; 64] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

const H0: [u32; 8] = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
];

#[inline]
fn rotr(x: u32, n: u32) -> u32 {
    (x >> n) | (x << (32 - n))
}

fn sha256_block(b: &[u8; 64], h: &mut [u32; 8]) {
    let mut w = [0u32; 64];
    for i in 0..16 {
        w[i] = ((b[i * 4] as u32) << 24)
            | ((b[i * 4 + 1] as u32) << 16)
            | ((b[i * 4 + 2] as u32) << 8)
            | (b[i * 4 + 3] as u32);
    }
    for i in 16..64 {
        let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
        let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = w[i - 16]
            .wrapping_add(s0)
            .wrapping_add(w[i - 7])
            .wrapping_add(s1);
    }
    let mut a = h[0];
    let mut bb = h[1];
    let mut c = h[2];
    let mut d = h[3];
    let mut e = h[4];
    let mut f = h[5];
    let mut g = h[6];
    let mut hh = h[7];
    for i in 0..64 {
        let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
        let ch = (e & f) ^ ((!e) & g);
        let t1 = hh
            .wrapping_add(s1)
            .wrapping_add(ch)
            .wrapping_add(K[i])
            .wrapping_add(w[i]);
        let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
        let maj = (a & bb) ^ (a & c) ^ (bb & c);
        let t2 = s0.wrapping_add(maj);
        hh = g;
        g = f;
        f = e;
        e = d.wrapping_add(t1);
        d = c;
        c = bb;
        bb = a;
        a = t1.wrapping_add(t2);
    }
    h[0] = h[0].wrapping_add(a);
    h[1] = h[1].wrapping_add(bb);
    h[2] = h[2].wrapping_add(c);
    h[3] = h[3].wrapping_add(d);
    h[4] = h[4].wrapping_add(e);
    h[5] = h[5].wrapping_add(f);
    h[6] = h[6].wrapping_add(g);
    h[7] = h[7].wrapping_add(hh);
}

// hash the 32-byte digest in place (one padded 64-byte block; message length = 256 bits)
fn sha256_32(digest: &mut [u8; 32]) {
    let mut b = [0u8; 64];
    b[..32].copy_from_slice(digest);
    b[32] = 0x80;
    b[62] = 1; // length 256 = 0x0100
    let mut h = H0;
    sha256_block(&b, &mut h);
    for i in 0..8 {
        digest[i * 4] = (h[i] >> 24) as u8;
        digest[i * 4 + 1] = (h[i] >> 16) as u8;
        digest[i * 4 + 2] = (h[i] >> 8) as u8;
        digest[i * 4 + 3] = h[i] as u8;
    }
}

fn main() {
    let n: i32 = env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(10000);
    let mut d = [0u8; 32];
    let mut s: i64 = 42;
    for i in 0..32 {
        s = (s.wrapping_mul(1103515245).wrapping_add(12345)) & 0x7fffffff;
        d[i] = (s % 256) as u8;
    }
    for _ in 0..n {
        sha256_32(&mut d);
    }
    let mut h: i64 = 0;
    for i in 0..32 {
        h = (h * 31 + d[i] as i64) % P;
    }
    println!("{}", h);
    println!("sha256({})", n);
}
