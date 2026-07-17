"use strict";

// sha256: hand-written real FIPS 180-4 SHA-256, applied iteratively N times to a
// 32-byte digest. Strict unsigned-32-bit arithmetic throughout: `>>> 0` after every
// addition chain forces the correct unsigned wraparound, and `>>>` is a logical
// (zero-fill) right shift. No multiplication is needed in the compression function,
// so Math.imul is not required here (unlike the LCG benchmarks).

const P = 1000000007;

const K = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

const H0 = [
  0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
  0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
];

function rotr(x, n) {
  return ((x >>> n) | (x << (32 - n))) >>> 0;
}

const W = new Uint32Array(64);

function sha256Block(b, h) {
  for (let i = 0; i < 16; i++) {
    W[i] = ((b[i * 4] << 24) | (b[i * 4 + 1] << 16) | (b[i * 4 + 2] << 8) | b[i * 4 + 3]) >>> 0;
  }
  for (let i = 16; i < 64; i++) {
    const s0 = (rotr(W[i - 15], 7) ^ rotr(W[i - 15], 18) ^ (W[i - 15] >>> 3)) >>> 0;
    const s1 = (rotr(W[i - 2], 17) ^ rotr(W[i - 2], 19) ^ (W[i - 2] >>> 10)) >>> 0;
    W[i] = (W[i - 16] + s0 + W[i - 7] + s1) >>> 0;
  }
  let a = h[0], bb = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
  for (let i = 0; i < 64; i++) {
    const S1 = (rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)) >>> 0;
    const ch = ((e & f) ^ (~e & g)) >>> 0;
    const t1 = (hh + S1 + ch + K[i] + W[i]) >>> 0;
    const S0 = (rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)) >>> 0;
    const maj = ((a & bb) ^ (a & c) ^ (bb & c)) >>> 0;
    const t2 = (S0 + maj) >>> 0;
    hh = g;
    g = f;
    f = e;
    e = (d + t1) >>> 0;
    d = c;
    c = bb;
    bb = a;
    a = (t1 + t2) >>> 0;
  }
  h[0] = (h[0] + a) >>> 0;
  h[1] = (h[1] + bb) >>> 0;
  h[2] = (h[2] + c) >>> 0;
  h[3] = (h[3] + d) >>> 0;
  h[4] = (h[4] + e) >>> 0;
  h[5] = (h[5] + f) >>> 0;
  h[6] = (h[6] + g) >>> 0;
  h[7] = (h[7] + hh) >>> 0;
}

function sha256_32(digest) {
  const b = new Uint8Array(64);
  b.set(digest.subarray(0, 32), 0);
  b[32] = 0x80;
  b[62] = 1;
  const h = new Uint32Array(H0);
  sha256Block(b, h);
  for (let i = 0; i < 8; i++) {
    digest[i * 4] = (h[i] >>> 24) & 0xff;
    digest[i * 4 + 1] = (h[i] >>> 16) & 0xff;
    digest[i * 4 + 2] = (h[i] >>> 8) & 0xff;
    digest[i * 4 + 3] = h[i] & 0xff;
  }
}

function lcgNext(s) {
  return (Math.imul(s, 1103515245) + 12345) & 0x7fffffff;
}

function sha256(n) {
  const d = new Uint8Array(32);
  let s = 42;
  for (let i = 0; i < 32; i++) {
    s = lcgNext(s);
    d[i] = s % 256;
  }
  for (let i = 0; i < n; i++) {
    sha256_32(d);
  }
  let h = 0;
  for (let i = 0; i < 32; i++) {
    h = (h * 31 + d[i]) % P;
  }
  return h;
}

function main() {
  const n = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : 10000;
  console.log(sha256(n));
  console.log(`sha256(${n})`);
}

main();
