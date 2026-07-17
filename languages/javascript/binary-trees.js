"use strict";

class Node {
  constructor(left, right) {
    this.left = left;
    this.right = right;
  }
}

function make(depth) {
  if (depth === 0) return new Node(null, null);
  return new Node(make(depth - 1), make(depth - 1));
}

function check(node) {
  if (node.left === null) return 1;
  return 1 + check(node.left) + check(node.right);
}

function binaryTrees(n) {
  const minDepth = 4;
  const maxDepth = Math.max(minDepth + 2, n);
  const stretchDepth = maxDepth + 1;

  let total = check(make(stretchDepth));
  const longLived = make(maxDepth);

  let depth = minDepth;
  while (depth <= maxDepth) {
    const iterations = 1 << (maxDepth - depth + minDepth);
    let s = 0;
    for (let i = 0; i < iterations; i++) {
      s += check(make(depth));
    }
    total += s;
    depth += 2;
  }

  total += check(longLived);
  return total;
}

function main() {
  const n = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : 10;
  console.log(binaryTrees(n));
  console.log(`binary-trees(${n})`);
}

main();
