"use strict";

// lz77: hand-written LZ77 compressor (WINDOW=512, 6-symbol alphabet), brute-force
// longest-match scan (nearest-distance wins ties), greedy parse. See sort-search.js
// for why the LCG uses Math.imul.

const P = 1000000007;
const WINDOW = 512;
const MIN_MATCH = 3;
const MAX_MATCH = 255;
const ALPHA = 6;

function lcg(s) {
  return (Math.imul(s, 1103515245) + 12345) & 0x7fffffff;
}

function lz77(n) {
  const data = new Uint8Array(n);
  let s = 42;
  for (let i = 0; i < n; i++) {
    s = lcg(s);
    data[i] = s % ALPHA;
  }

  let pos = 0;
  let h = 0;
  while (pos < n) {
    let bestLen = 0;
    let bestDist = 0;
    let start = pos - WINDOW;
    if (start < 0) start = 0;
    let cand = pos - 1;
    while (cand >= start) {
      // nearest distance first
      let l = 0;
      while (pos + l < n && l < MAX_MATCH && data[cand + l] === data[pos + l]) {
        l += 1;
      }
      if (l > bestLen) {
        // strict > : closest wins ties
        bestLen = l;
        bestDist = pos - cand;
      }
      cand -= 1;
    }
    if (bestLen >= MIN_MATCH) {
      h = (h * 31 + 1) % P;
      h = (h * 31 + bestDist) % P;
      h = (h * 31 + bestLen) % P;
      pos += bestLen;
    } else {
      h = (h * 31 + 0) % P;
      h = (h * 31 + data[pos]) % P;
      pos += 1;
    }
  }
  return h;
}

function main() {
  const n = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : 24000;
  console.log(lz77(n));
  console.log(`lz77(${n})`);
}

main();
