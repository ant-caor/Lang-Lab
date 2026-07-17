"use strict";

// Mandelbrot set over an N x N grid of the complex plane [-1.5, 0.5] x [-1.0, 1.0].
// A pixel is "in the set" if |z| stays <= 2 (i.e. zr^2+zi^2 <= 4) through 50 iterations
// of z := z^2 + c starting from z = 0. The checksum is the count of in-set pixels.
//
// JS numbers are IEEE-754 binary64 (C double). The 2*zr*zi term is written as t+t
// (t = zr*zi) instead of 2.0*zr*zi so there is NO multiply-add pattern to FMA-contract;
// t+t is bit-identical to 2.0*t. This keeps the result bit-exact across every language.

function mandelbrot(n) {
  let count = 0;
  for (let y = 0; y < n; y++) {
    const ci = (2.0 * y) / n - 1.0;
    for (let x = 0; x < n; x++) {
      const cr = (2.0 * x) / n - 1.5;
      let zr = 0.0;
      let zi = 0.0;
      let tr = 0.0;
      let ti = 0.0;
      let i = 0;
      while (i < 50 && tr + ti <= 4.0) {
        const t = zr * zi;
        zi = t + t + ci; // == 2*zr*zi + ci, FMA-proof
        zr = tr - ti + cr;
        tr = zr * zr;
        ti = zi * zi;
        i += 1;
      }
      if (tr + ti <= 4.0) count += 1; // never escaped -> in set
    }
  }
  return count;
}

function main() {
  const n = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : 128;
  console.log(mandelbrot(n));
  console.log(`mandelbrot(${n})`);
}

main();
