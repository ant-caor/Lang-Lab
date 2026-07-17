"use strict";

// gbdt: gradient-boosted decision-tree ensemble inference - the dominant tabular-ML
// algorithm (XGBoost/LightGBM/CatBoost style). B=200 trees of depth D=8 over F=8
// features. Each tree is a flat complete binary tree (NODES=511): internal nodes
// 0..254 store a (feature-index, threshold) split; leaves 255..510 store a value.
// Children of node k: left=2k+1, right=2k+2. Inference: for each sample, traverse
// all B trees (exactly D compare-and-branch steps each) and sum the leaf values.
// Checksum: poly-hash of (acc+1) per sample; secondary = sum of acc values mod P.
// LCG draw order pinned: feat then thr per internal node, leafval per leaf, samples.
// All integer - no float, no ML/tree library. See sort-search.js for why the LCG
// uses Math.imul.

const P = 1000000007;
const D = 8;
const B = 200;
const F = 8;
const NODES = (1 << (D + 1)) - 1; // 511
const LEAF_START = (1 << D) - 1; // 255

function lcg(s) {
  return (Math.imul(s, 1103515245) + 12345) & 0x7fffffff;
}

function gbdt(n) {
  const feat = new Int32Array(B * NODES);
  const thr = new Int32Array(B * NODES);
  const leafval = new Int32Array(B * NODES);

  let state = 42;
  for (let b = 0; b < B; b++) {
    const base = b * NODES;
    for (let node = 0; node < LEAF_START; node++) {
      // internal nodes: feat then thr
      state = lcg(state);
      feat[base + node] = state % F;
      state = lcg(state);
      thr[base + node] = state % 256;
    }
    for (let node = LEAF_START; node < NODES; node++) {
      // leaves
      state = lcg(state);
      leafval[base + node] = state % 10;
    }
  }

  const sample = new Int32Array(n * F);
  for (let i = 0; i < n * F; i++) {
    state = lcg(state);
    sample[i] = state % 256;
  }

  let h = 0;
  let total = 0;
  for (let i = 0; i < n; i++) {
    const sbase = i * F;
    let acc = 0;
    for (let b = 0; b < B; b++) {
      const tbase = b * NODES;
      let node = 0;
      for (let step = 0; step < D; step++) {
        if (sample[sbase + feat[tbase + node]] <= thr[tbase + node]) {
          node = 2 * node + 1;
        } else {
          node = 2 * node + 2;
        }
      }
      acc += leafval[tbase + node];
    }
    h = (h * 31 + acc + 1) % P;
    total = (total + acc) % P;
  }

  return [h, total];
}

function main() {
  const n = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : 5000;
  const [h, sec] = gbdt(n);
  console.log(h);
  console.log(`gbdt(${n}) = ${sec}`);
}

main();
