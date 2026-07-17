"use strict";

// polymorphism: dynamic-dispatch / virtual-call-overhead axis. N objects of K=6 concrete
// types in an unpredictable (megamorphic) order; fold acc through all of them M times via
// obj.apply(acc). Each type has its own apply() formula; the acc threads through every
// call so nothing can be hoisted (exactly N*M real dispatches). JS uses idiomatic
// prototype-based method dispatch (six distinct classes behind one polymorphic call site).
// Checksum = the final accumulator. All integer. See sort-search.js for why the LCG uses
// Math.imul.

const P = 1000000007;
const N = 10000;
const K = 6;

// Distinct large multipliers so the per-pass composition never reaches a fixed point: acc
// stays chaotic and the checksum depends on M (proof all N*M dispatches ran).
class T0 {
  constructor(a, b, c) {
    this.a = a;
    this.b = b;
    this.c = c;
  }
  apply(x) {
    return (x * 1000003 + this.a) % P;
  }
}

class T1 extends T0 {
  apply(x) {
    return (x * 998273 + this.b) % P;
  }
}

class T2 extends T0 {
  apply(x) {
    return (x * 999983 + this.c) % P;
  }
}

class T3 extends T0 {
  apply(x) {
    return (x * 997879 + this.a + this.b) % P;
  }
}

class T4 extends T0 {
  apply(x) {
    return (x * 996323 + this.b * this.c) % P;
  }
}

class T5 extends T0 {
  apply(x) {
    return (x * 995369 + this.a + this.c) % P;
  }
}

const TYPES = [T0, T1, T2, T3, T4, T5];

function lcg(s) {
  return (Math.imul(s, 1103515245) + 12345) & 0x7fffffff;
}

function main() {
  const M = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : 50;
  let s = 42;
  const objs = new Array(N);
  for (let i = 0; i < N; i++) {
    s = lcg(s);
    const t = (s >>> 16) % K; // type from HIGH bits (LCG low bits correlate); all K used
    s = lcg(s);
    const a = s % 1000;
    s = lcg(s);
    const b = s % 1000;
    s = lcg(s);
    const c = s % 1000;
    const Ctor = TYPES[t];
    objs[i] = new Ctor(a, b, c);
  }
  let acc = 1;
  for (let pass = 0; pass < M; pass++) {
    for (let i = 0; i < N; i++) {
      acc = objs[i].apply(acc);
    }
  }
  console.log(acc);
  console.log(`polymorphism(${M})`);
}

main();
