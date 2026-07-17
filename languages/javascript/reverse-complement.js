"use strict";

const P = 1000000007;
const IM = 139968;
const IA = 3877;
const IC = 29573;

function comp(c) {
  // A<->T, C<->G; only A/C/G/T occur
  if (c === 65) return 84; // 'A' -> 'T'
  if (c === 67) return 71; // 'C' -> 'G'
  if (c === 71) return 67; // 'G' -> 'C'
  return 65; // 'T' -> 'A'
}

function reverseComplement(L) {
  const s = new Uint8Array(L);
  let seed = 42;
  for (let i = 0; i < L; i++) {
    seed = (seed * IA + IC) % IM;
    if (seed < 42000) s[i] = 65; // 'A'
    else if (seed < 70000) s[i] = 67; // 'C'
    else if (seed < 98000) s[i] = 71; // 'G'
    else s[i] = 84; // 'T'
  }

  let i = 0;
  let j = L - 1;
  while (i < j) {
    // two-pointer reverse-and-complement, in place
    const a = comp(s[i]);
    s[i] = comp(s[j]);
    s[j] = a;
    i += 1;
    j -= 1;
  }
  if (i === j) s[i] = comp(s[i]); // middle char when L is odd

  let h = 0;
  for (let k = 0; k < L; k++) {
    h = (h * 31 + s[k]) % P;
  }
  return h;
}

function main() {
  const L = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : 100000;
  console.log(reverseComplement(L));
  console.log(`reverse-complement(${L})`);
}

main();
