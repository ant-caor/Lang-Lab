"use strict";

// k-means: hand-written integer Lloyd's clustering (K=16, D=4, ITERS=10). See
// sort-search.js for why the LCG uses Math.imul.

const P = 1000000007;
const K = 16;
const D = 4;
const ITERS = 10;
const RANGE = 256;

function lcgNext(s) {
  return (Math.imul(s, 1103515245) + 12345) & 0x7fffffff;
}

function kMeans(n) {
  // 1. Generate N integer D-dimensional points with the pinned LCG
  const pt = new Int32Array(n * D);
  let state = 42;
  for (let i = 0; i < n * D; i++) {
    state = lcgNext(state);
    pt[i] = state % RANGE;
  }
  const cen = new Int32Array(K * D);
  for (let i = 0; i < K * D; i++) cen[i] = pt[i]; // initial centroids = first K points
  const assign = new Int32Array(n);

  // 2. ITERS iterations of assign + update
  for (let iter = 0; iter < ITERS; iter++) {
    for (let i = 0; i < n; i++) {
      // assignment - nearest centroid
      const base = i * D;
      let best = 0;
      let bd = -1;
      for (let k = 0; k < K; k++) {
        const kb = k * D;
        let dist = 0;
        for (let d = 0; d < D; d++) {
          const df = pt[base + d] - cen[kb + d];
          dist += df * df;
        }
        if (bd < 0 || dist < bd) {
          // STRICT < : ties go to the lowest k
          bd = dist;
          best = k;
        }
      }
      assign[i] = best;
    }
    const ssum = new Int32Array(K * D); // update - floor-mean, empty unchanged
    const cnt = new Int32Array(K);
    for (let i = 0; i < n; i++) {
      const k = assign[i];
      cnt[k] += 1;
      const base = i * D;
      const kb = k * D;
      for (let d = 0; d < D; d++) {
        ssum[kb + d] += pt[base + d];
      }
    }
    for (let k = 0; k < K; k++) {
      if (cnt[k] > 0) {
        const kb = k * D;
        const c = cnt[k];
        for (let d = 0; d < D; d++) {
          cen[kb + d] = Math.floor(ssum[kb + d] / c); // INTEGER (floor) division
        }
      }
    }
  }

  for (let i = 0; i < n; i++) {
    // final assignment with final centroids
    const base = i * D;
    let best = 0;
    let bd = -1;
    for (let k = 0; k < K; k++) {
      const kb = k * D;
      let dist = 0;
      for (let d = 0; d < D; d++) {
        const df = pt[base + d] - cen[kb + d];
        dist += df * df;
      }
      if (bd < 0 || dist < bd) {
        bd = dist;
        best = k;
      }
    }
    assign[i] = best;
  }

  let h = 0;
  for (let v = 0; v < K * D; v++) {
    h = (h * 31 + cen[v]) % P;
  }
  for (let i = 0; i < n; i++) {
    h = (h * 31 + assign[i]) % P;
  }
  return h;
}

function main() {
  const n = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : 8000;
  console.log(kMeans(n));
  console.log(`k-means(${n})`);
}

main();
