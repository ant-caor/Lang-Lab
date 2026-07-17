"use strict";

// tak: Takeuchi function - the function-call / recursion-overhead axis. Naive triple
// recursion, no memoization, no iterative rewrite. Checksum = total number of calls
// (identical-recursion invariant); secondary = the returned value. Size n -> tak(3n, 2n, n).
// Pure integer, no memory.

let calls = 0;

function tak(x, y, z) {
  calls += 1;
  if (y < x) {
    return tak(tak(x - 1, y, z), tak(y - 1, z, x), tak(z - 1, x, y));
  }
  return z;
}

function main() {
  const n = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : 6;
  const r = tak(3 * n, 2 * n, n);
  console.log(calls);
  console.log(`tak(${n}) = ${r}`);
}

main();
