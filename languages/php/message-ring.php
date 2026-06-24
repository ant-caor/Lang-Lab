<?php

// message-ring: cooperative concurrency / message-passing overhead axis.
// 32 Fibers in a ring driven by main for N laps. Each worker receives a token v,
// applies the glibc LCG transform v = (v * 1103515245 + (id+1)) & 0xFFFFFFFF,
// and forwards to the next fiber. Worker 31 yields the transformed token back to main.
// Primitive: PHP Fibers (PHP 8.1+). Single OS thread by construction.

const RING_WIDTH = 32;
const SEED       = 12345;
const MOD        = 1000000007;

$n = isset($argv[1]) ? (int)$argv[1] : 2000;

// $result is written by worker 31 before it suspends, then read by main.
// This is the only shared state; the actual context switch (the cost being measured)
// is the Fiber::suspend() / ->resume() pair on every hop.
$result = 0;

/** @var Fiber[] $fibers */
$fibers = [];

// Create 32 worker fibers. Each runs a loop for $n laps:
//   1. suspend (waits for main or the previous worker to resume it with a token)
//   2. apply the LCG transform
//   3. forward to the next fiber (or write result + suspend for worker 31)
for ($id = 0; $id < RING_WIDTH; $id++) {
    $fibers[$id] = new Fiber(function () use ($id, $n, &$fibers, &$result): void {
        for ($lap = 0; $lap < $n; $lap++) {
            // Receive token from the previous worker (or from main for id=0).
            $v = Fiber::suspend();
            // Apply deterministic transform (32-bit unsigned wrap).
            $v = ($v * 1103515245 + ($id + 1)) & 0xFFFFFFFF;
            if ($id < RING_WIDTH - 1) {
                // Forward to the next worker in the ring.
                $fibers[$id + 1]->resume($v);
            } else {
                // Worker 31: store result for main. No extra suspend needed --
                // the cascade of each prior fiber looping to its next-lap
                // Fiber::suspend() unwinds control back to main automatically.
                $result = $v;
            }
        }
    });
}

// Prime each fiber: run it until its first Fiber::suspend() (receives nothing yet,
// just parks itself ready for the first lap).
for ($id = 0; $id < RING_WIDTH; $id++) {
    $fibers[$id]->start();
}

// Main lap loop: hand token to worker 0, receive it back from worker 31.
$v = SEED;
for ($lap = 0; $lap < $n; $lap++) {
    $fibers[0]->resume($v);
    // Worker 31 has written $result and suspended; the resume chain has unwound back here.
    $v = $result;
}

echo $v % MOD, "\n";
echo $n * RING_WIDTH, "\n";
