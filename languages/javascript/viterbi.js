"use strict";

// viterbi: integer HMM sequence decoding - the classical max-plus trellis.
// S=8 states, ALPHA=4 symbols, T=size parameter. LCG (glibc-style, seed=42)
// draws trans[S*S], emit[S*ALPHA], obs[T] in that order. Forward pass is a
// loop-carried max-reduction (STRICT > tie-break: lowest i wins), followed by a
// pointer-chain backtrace. Checksum = poly-hash of (path[t]+1).
// Secondary = optimal total path score mod P. No HMM library; pure integer.
// See sort-search.js for why the LCG uses Math.imul.

const S = 8;
const ALPHA = 4;
const P = 1000000007;

function lcg(s) {
  return (Math.imul(s, 1103515245) + 12345) & 0x7fffffff;
}

function viterbi(t) {
  // Draw order: trans[S*S], emit[S*ALPHA], obs[T]
  let state = 42;
  const trans = new Int32Array(S * S);
  for (let x = 0; x < S * S; x++) {
    state = lcg(state);
    trans[x] = (state % 100) + 1;
  }

  const emit = new Int32Array(S * ALPHA);
  for (let x = 0; x < S * ALPHA; x++) {
    state = lcg(state);
    emit[x] = (state % 100) + 1;
  }

  const obs = new Int32Array(t);
  for (let i = 0; i < t; i++) {
    state = lcg(state);
    obs[i] = state % ALPHA;
  }

  // Initialise t=0
  let vitPrev = new Float64Array(S);
  for (let j = 0; j < S; j++) vitPrev[j] = emit[j * ALPHA + obs[0]];
  let vitNext = new Float64Array(S);

  // back[t*S+j]
  const back = new Int32Array(t * S);

  // Forward trellis t=1..T-1
  for (let ti = 1; ti < t; ti++) {
    for (let j = 0; j < S; j++) {
      let best = -1;
      let bi = 0;
      const emitBase = j * ALPHA + obs[ti];
      const e = emit[emitBase];
      for (let i = 0; i < S; i++) {
        const sc = vitPrev[i] + trans[i * S + j] + e;
        if (sc > best) {
          // STRICT > -> lowest i wins ties
          best = sc;
          bi = i;
        }
      }
      vitNext[j] = best;
      back[ti * S + j] = bi;
    }
    const tmp = vitPrev; vitPrev = vitNext; vitNext = tmp;
  }

  // Final state: STRICT > -> lowest j wins
  let bf = 0;
  for (let j = 1; j < S; j++) {
    if (vitPrev[j] > vitPrev[bf]) bf = j;
  }

  // Backtrace
  const path = new Int32Array(t);
  path[t - 1] = bf;
  for (let ti = t - 2; ti >= 0; ti--) {
    path[ti] = back[(ti + 1) * S + path[ti + 1]];
  }

  // Checksum
  let h = 0;
  for (let ti = 0; ti < t; ti++) {
    h = (h * 31 + path[ti] + 1) % P;
  }

  const secondary = vitPrev[bf] % P;
  return [h, secondary];
}

function main() {
  const n = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : 20000;
  const [h, sec] = viterbi(n);
  console.log(h);
  console.log(`viterbi(${n}) = ${sec}`);
}

main();
