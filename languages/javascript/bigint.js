"use strict";

// bigint: hand-rolled base-2^32 limb factorial N! (NOT using JS's native BigInt, which
// would defeat the point of the benchmark). cur = limb*k + carry stays well below 2^53
// for these N (~2^46 at worst), so plain Number arithmetic is exact. `cur >>> 0` extracts
// the low 32 bits (JS's ToUint32 computes an exact mathematical modulo, not a truncation
// of a 32-bit register, so it stays correct for cur far above 2^32). `Math.floor(cur /
// 4294967296)` extracts the high bits since JS's native `>>` only operates on 32-bit
// truncated operands and would silently discard everything above bit 31.

const P = 1000000007;
const BASE = 4294967296; // 2^32

function bigint(n) {
  let limbs = [1]; // least-significant limb first; base 2^32
  let length = 1;
  for (let k = 2; k <= n; k++) {
    let carry = 0;
    for (let i = 0; i < length; i++) {
      const cur = limbs[i] * k + carry; // exact double, well under 2^53
      limbs[i] = cur >>> 0; // low 32 bits
      carry = Math.floor(cur / BASE); // high bits propagate
    }
    while (carry > 0) {
      limbs.push(carry >>> 0);
      length += 1;
      carry = Math.floor(carry / BASE);
    }
  }
  let h = 0;
  for (let i = 0; i < limbs.length; i++) {
    // poly-hash, least-significant first
    h = (h * 31 + limbs[i]) % P;
  }
  return h;
}

function main() {
  const n = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : 6000;
  console.log(bigint(n));
  console.log(`bigint(${n})`);
}

main();
