"use strict";

const K = 8;
const P = 1000000007;
const IM = 139968;
const IA = 3877;
const IC = 29573;

const CODE = { A: 0, C: 1, G: 2, T: 3 };

function gen(length) {
  let seed = 42;
  const chars = new Array(length);
  for (let i = 0; i < length; i++) {
    seed = (seed * IA + IC) % IM;
    if (seed < 42000) chars[i] = "A";
    else if (seed < 70000) chars[i] = "C";
    else if (seed < 98000) chars[i] = "G";
    else chars[i] = "T";
  }
  return chars.join("");
}

function kNucleotide(length) {
  const s = gen(length);

  const counts = new Map();
  for (let i = 0; i <= length - K; i++) {
    const kmer = s.substring(i, i + K);
    counts.set(kmer, (counts.get(kmer) || 0) + 1);
  }

  let acc = 0;
  for (const [kmer, count] of counts) {
    let e = 0;
    for (let j = 0; j < kmer.length; j++) {
      e = e * 4 + CODE[kmer[j]];
    }
    acc = (acc + e * count) % P;
  }
  return acc;
}

function main() {
  const n = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : 100000;
  console.log(kNucleotide(n));
  console.log(`k-nucleotide(${n})`);
}

main();
