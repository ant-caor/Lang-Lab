"use strict";

// sort-search: generate N integers, sort them with a hand-written median-of-three
// quicksort (Hoare partition), then run N binary searches and fold the found indices
// into a checksum. The two classic algorithms - quicksort and binary search - written
// out explicitly (no stdlib sort/bisect), so this measures the LANGUAGE executing the
// SAME algorithm, consistent with the suite's no-stdlib-shortcut rule. All integer.
//
// Number-safety note: the reference computes `state * 1103515245` in full 64-bit
// precision before masking to 31 bits. That product can reach ~2.4e10 * ... well above
// 2^53 (JS's safe-integer ceiling), so a plain `state * 1103515245` would silently lose
// the low bits we need. Masking to 0x7fffffff only ever depends on the low 32 bits of
// the product (mod 2^31 is a subset of mod 2^32), so Math.imul (exact 32-bit-truncated
// multiply) gives the identical result to the full 64-bit computation - verified against
// a BigInt reference over 200000 iterations.

const P = 1000000007;

function lcgNext(s) {
  return (Math.imul(s, 1103515245) + 12345) & 0x7fffffff;
}

// median-of-three + Hoare partition, recurse both sides; depth stays ~log N.
function qsortH(a, lo, hi) {
  if (lo >= hi) return;
  const mid = lo + ((hi - lo) >> 1);
  if (a[mid] < a[lo]) {
    const t = a[lo]; a[lo] = a[mid]; a[mid] = t;
  }
  if (a[hi] < a[lo]) {
    const t = a[lo]; a[lo] = a[hi]; a[hi] = t;
  }
  if (a[hi] < a[mid]) {
    const t = a[mid]; a[mid] = a[hi]; a[hi] = t;
  }
  const pivot = a[mid];
  let i = lo - 1;
  let j = hi + 1;
  for (;;) {
    do { i += 1; } while (a[i] < pivot);
    do { j -= 1; } while (a[j] > pivot);
    if (i >= j) break;
    const t = a[i]; a[i] = a[j]; a[j] = t;
  }
  qsortH(a, lo, j);
  qsortH(a, j + 1, hi);
}

function bsearchI(a, n, key) {
  let lo = 0;
  let hi = n - 1;
  while (lo <= hi) {
    const mid = lo + ((hi - lo) >> 1);
    if (a[mid] < key) lo = mid + 1;
    else if (a[mid] > key) hi = mid - 1;
    else return mid;
  }
  return -1;
}

function sortSearch(n) {
  const a = new Array(n);
  let state = 42;
  for (let i = 0; i < n; i++) {
    state = lcgNext(state);
    a[i] = state;
  }
  qsortH(a, 0, n - 1);
  let h = 0;
  for (let q = 0; q < n; q++) {
    state = lcgNext(state);
    const key = a[state % n]; // a value present in the sorted array -> a hit
    const idx = bsearchI(a, n, key);
    h = (h * 31 + (idx + 1)) % P;
  }
  return h;
}

function main() {
  const n = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : 100000;
  console.log(sortSearch(n));
  console.log(`sort-search(${n})`);
}

main();
