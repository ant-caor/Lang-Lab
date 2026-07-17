"use strict";

function fannkuch(n) {
  const perm1 = new Int32Array(n);
  for (let i = 0; i < n; i++) perm1[i] = i;
  const perm = new Int32Array(n);
  const count = new Int32Array(n);
  let maxFlips = 0;
  let checksum = 0;
  let permIdx = 0;
  let r = n;

  for (;;) {
    while (r !== 1) {
      count[r - 1] = r;
      r--;
    }

    perm.set(perm1);
    let flips = 0;
    let k = perm[0];
    while (k !== 0) {
      let i = 0;
      let j = k;
      while (i < j) {
        const t = perm[i];
        perm[i] = perm[j];
        perm[j] = t;
        i++;
        j--;
      }
      flips++;
      k = perm[0];
    }

    if (flips > maxFlips) maxFlips = flips;
    checksum += permIdx % 2 === 0 ? flips : -flips;

    // Generate the next permutation.
    for (;;) {
      if (r === n) {
        return [maxFlips, checksum];
      }
      const first = perm1[0];
      for (let i = 0; i < r; i++) perm1[i] = perm1[i + 1];
      perm1[r] = first;
      count[r]--;
      if (count[r] > 0) break;
      r++;
    }
    permIdx++;
  }
}

function main() {
  const n = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : 7;
  const [maxFlips, checksum] = fannkuch(n);
  console.log(checksum);
  console.log(`Pfannkuchen(${n}) = ${maxFlips}`);
}

main();
