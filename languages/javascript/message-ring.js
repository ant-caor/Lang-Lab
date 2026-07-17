"use strict";

// message-ring: cooperative concurrency overhead axis.
// 32 async/await "coroutines" (Node's event loop is single-threaded) in a ring, driven
// by main for N laps. Each worker receives a token, applies the LCG transform, and
// forwards it. Primitive: a hand-rolled single-slot awaitable channel (the Promise-based
// equivalent of Python's asyncio.Queue(maxsize=1)); the default Node event loop runs on
// one OS thread by construction, satisfying the single-scheduler-thread requirement.
//
// The transform `v = (v*1103515245 + (id+1)) mod 2^32` needs Math.imul: v can be up to
// 2^32-1, and v*1103515245 reaches ~4.7e18, far past 2^53. Math.imul gives the exact
// low-32-bit product (mod 2^32 is all that survives the final mask anyway).

const RING_WIDTH = 32;
const SEED = 12345;
const MOD = 1000000007;

// A single-slot rendezvous channel: put() waits until the slot is empty, get() waits
// until the slot is full. Exactly one producer and one consumer contend on each channel
// in this workload, so a single pending resolver per side suffices.
class OneSlotChannel {
  constructor() {
    this._val = 0;
    this._full = false;
    this._putWaiter = null;
    this._getWaiter = null;
  }

  async put(v) {
    while (this._full) {
      await new Promise((resolve) => { this._putWaiter = resolve; });
    }
    this._val = v;
    this._full = true;
    if (this._getWaiter) {
      const w = this._getWaiter;
      this._getWaiter = null;
      w();
    }
  }

  async get() {
    while (!this._full) {
      await new Promise((resolve) => { this._getWaiter = resolve; });
    }
    const v = this._val;
    this._full = false;
    if (this._putWaiter) {
      const w = this._putWaiter;
      this._putWaiter = null;
      w();
    }
    return v;
  }
}

function lcgTransform(v, wid) {
  return (Math.imul(v, 1103515245) + (wid + 1)) >>> 0;
}

async function worker(wid, inbox, outbox, n) {
  for (let i = 0; i < n; i++) {
    let v = await inbox.get();
    v = lcgTransform(v, wid);
    await outbox.put(v);
  }
}

async function run(n) {
  // One channel per ring edge: queues[i] feeds worker i (worker i reads from queues[i],
  // writes to queues[i+1]). queues[RING_WIDTH] is shared with main (worker 31 -> main).
  const queues = [];
  for (let i = 0; i <= RING_WIDTH; i++) queues.push(new OneSlotChannel());

  const tasks = [];
  for (let i = 0; i < RING_WIDTH; i++) {
    tasks.push(worker(i, queues[i], queues[i + 1], n));
  }

  let v = SEED;
  for (let lap = 0; lap < n; lap++) {
    await queues[0].put(v);
    v = await queues[RING_WIDTH].get();
  }

  await Promise.all(tasks);
  return v;
}

async function main() {
  const n = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : 2000;
  const v = await run(n);
  console.log(v % MOD);
  console.log(n * RING_WIDTH);
}

main();
