// message-ring: the lightweight-concurrency / message-passing overhead axis. Every other
// benchmark measures pure compute, memory, or call cost; this one measures what it costs to
// hand a token from one cooperative unit to another - the tax for concurrency machinery beyond
// the work itself. It does NOT measure parallel speedup (the qemu insn plugin counts guest
// instructions, blind to multicore): the differential I(n2)-I(n1) isolates the per-hop cost of
// a cooperative context switch + message send.
//
// A ring of RING_WIDTH=32 workers (ids 0..31) is driven by main for N laps. main seeds v=SEED,
// then each lap sends v to worker 0; each worker transforms v = (v*1103515245 + (id+1)) mod 2^32
// and forwards it to the next (worker 31 hands back to main). 32-bit unsigned wrap is natural in
// uint32_t. The token visits workers in strict id order, so the final value is fully determined
// by N - no scheduler ordering can alter the checksum.
//
// C baseline (1.0x): POSIX ucontext_t + makecontext/swapcontext, the lowest-level faithful
// cooperative-yield primitive in C with no library hiding the cost. All 32 workers + main run on
// a single OS thread by construction (ucontext is single-threaded). The 32 coroutine stacks are
// allocated and the contexts spawned ONCE before the lap loop (spawning per lap would measure
// spawn cost, not hop cost). The transform happens INSIDE the worker, never folded into main.
//
// Checksum (line 1) = v mod MOD; secondary (line 2) = N*RING_WIDTH (total hops). All integer.
//
// ucontext_t is exposed by _XOPEN_SOURCE=700 (POSIX.1-2008 XSI) on glibc bookworm AND macOS,
// so the source compiles with a bare `gcc -O2` (no -D flags) as the C Dockerfile invokes it;
// _GNU_SOURCE is also defined so the glibc feature-test path matches the README's note.
#define _XOPEN_SOURCE 700
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <ucontext.h>

#define RING_WIDTH 32
#define SEED 12345u
#define MOD 1000000007L
#define STACK_SIZE (64 * 1024)

// Shared single-channel token: the only communication between cooperative units. The handoff is
// the swapcontext switch itself; this carries the value across the suspend/resume boundary.
static uint32_t token;

static ucontext_t main_ctx;            // the controller's context (worker 31 returns here)
static ucontext_t worker_ctx[RING_WIDTH];
static char worker_stack[RING_WIDTH][STACK_SIZE];

// Each worker is a coroutine bound to its id. It loops for the full N laps: receive the token
// (resumed via swapcontext), apply its transform, and yield to the next unit. Worker 31 yields
// back to main; every other worker yields to its successor. The loop runs N times then falls
// through (uc_link returns control to main on the final return, but we never rely on that count).
static void worker_fn(int id, int laps) {
    for (int lap = 0; lap < laps; lap++) {
        // receive: control arrives here with the current token in the shared cell
        token = (uint32_t)(token * 1103515245u + (uint32_t)(id + 1));
        // forward: hand the transformed token to the next unit and suspend until next resumed
        if (id == RING_WIDTH - 1)
            swapcontext(&worker_ctx[id], &main_ctx);
        else
            swapcontext(&worker_ctx[id], &worker_ctx[id + 1]);
    }
}

int main(int argc, char **argv) {
    int n = argc > 1 ? atoi(argv[1]) : 500;

    // Spawn all 32 coroutines ONCE. makecontext takes int args, so id and laps are passed as
    // two ints. uc_link is unused for the steady-state handoff (workers swapcontext explicitly),
    // but is set to main_ctx so a worker that runs out of laps returns cleanly instead of UB.
    for (int id = 0; id < RING_WIDTH; id++) {
        getcontext(&worker_ctx[id]);
        worker_ctx[id].uc_stack.ss_sp = worker_stack[id];
        worker_ctx[id].uc_stack.ss_size = STACK_SIZE;
        worker_ctx[id].uc_link = &main_ctx;
        makecontext(&worker_ctx[id], (void (*)(void))worker_fn, 2, id, n);
    }

    token = SEED;
    for (int lap = 0; lap < n; lap++) {
        // send v to worker 0; control returns here when worker 31 hands back (one full lap)
        swapcontext(&main_ctx, &worker_ctx[0]);
        // receive v from worker 31: it is already in `token`
    }

    long v = (long)token % MOD;
    printf("%ld\n", v);
    printf("%ld\n", (long)n * RING_WIDTH);
    return 0;
}
