"use strict";

// gemm: quantized integer matrix-multiply - the dominant ML inference kernel.
// Square matmul of side N (i.e. N x N matrices). Loop order i,k,j (pinned)
// so B is accessed row-sequentially. LCG fills A then B with values 0..127.
// Accumulator stays well within a safe integer; checksum = poly-hash of C row-major
// mod 1e9+7. No BLAS / no library matmul - the explicit triple loop. See sort-search.js
// for why the LCG uses Math.imul.

const P = 1000000007;

function lcgNext(s) {
  return (Math.imul(s, 1103515245) + 12345) & 0x7fffffff;
}

function gemm(n) {
  const A = new Float64Array(n * n);
  const B = new Float64Array(n * n);

  let state = 42;
  for (let i = 0; i < n * n; i++) {
    state = lcgNext(state);
    A[i] = state % 128;
  }
  for (let i = 0; i < n * n; i++) {
    state = lcgNext(state);
    B[i] = state % 128;
  }

  const C = new Float64Array(n * n);
  // Pinned loop order i, k, j - B read row-sequentially.
  for (let i = 0; i < n; i++) {
    const base = i * n;
    for (let k = 0; k < n; k++) {
      const a = A[i * n + k];
      const kn = k * n;
      for (let j = 0; j < n; j++) {
        C[base + j] += a * B[kn + j];
      }
    }
  }

  let h = 0;
  for (let idx = 0; idx < n * n; idx++) {
    h = (h * 31 + (C[idx] % P)) % P;
  }
  const secondary = C[n * n - 1] % P;
  return [h, secondary];
}

function main() {
  const n = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : 256;
  const [h, sec] = gemm(n);
  console.log(h);
  console.log(`gemm(${n}) = ${sec}`);
}

main();
