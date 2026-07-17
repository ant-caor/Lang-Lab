"use strict";

// blur: 3x3 Gaussian blur over an LCG-generated grayscale image, double-buffered,
// PASSES=4, clamp (edge-replication) borders. See sort-search.js for why the LCG
// uses Math.imul.

const P = 1000000007;
const PASSES = 4;
const K = [1, 2, 1, 2, 4, 2, 1, 2, 1]; // 3x3, sum 16

function lcgNext(s) {
  return (Math.imul(s, 1103515245) + 12345) & 0x7fffffff;
}

function clampi(x, n) {
  if (x < 0) return 0;
  if (x >= n) return n - 1;
  return x;
}

function blur(n) {
  let src = new Int32Array(n * n);
  let dst = new Int32Array(n * n);

  let s = 42;
  for (let k = 0; k < n * n; k++) {
    s = lcgNext(s);
    src[k] = s % 256;
  }

  for (let pass = 0; pass < PASSES; pass++) {
    for (let i = 0; i < n; i++) {
      for (let j = 0; j < n; j++) {
        let acc = 0;
        for (let di = -1; di <= 1; di++) {
          const ni = clampi(i + di, n);
          for (let dj = -1; dj <= 1; dj++) {
            const nj = clampi(j + dj, n);
            acc += K[(di + 1) * 3 + (dj + 1)] * src[ni * n + nj];
          }
        }
        dst[i * n + j] = Math.floor(acc / 16); // integer division
      }
    }
    const t = src; src = dst; dst = t; // double-buffer swap
  }

  let h = 0;
  for (let k = 0; k < n * n; k++) {
    h = (h * 31 + src[k]) % P;
  }
  return h;
}

function main() {
  const n = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : 256;
  console.log(blur(n));
  console.log(`blur(${n})`);
}

main();
