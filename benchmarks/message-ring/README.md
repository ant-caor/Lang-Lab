# message-ring: study

The **lightweight-concurrency / message-passing overhead** axis. Every other benchmark in the
suite measures pure compute, memory, or call cost; this one measures what it costs to *hand a
token from one cooperative unit to another* -- the tax paid for concurrency machinery beyond
the work itself.

## What this benchmark measures (and what it does NOT)

**It measures the per-handoff instruction cost of each language's cooperative concurrency
primitive**, not any parallel speedup.

This distinction is critical and must be stated plainly:

- lang-lab's metric is the differential `I(n2) - I(n1)` of **guest instruction counts**
  recorded by qemu-user's TCG `insn` plugin. The plugin sums guest instructions across all
  vCPUs; it is blind to multicore speedup, which is a wall-clock phenomenon.
- There is therefore no concept of "faster because more cores" in this suite. A 4-core Go
  program and a 1-core Go program execute a different number of *total* instructions to do
  the same work; the benchmark is designed so that number is the interesting quantity.
- What the differential isolates: **the instruction overhead per cooperative context switch /
  message send**. A language that dispatches a token with fewer instructions per hop has a
  lighter concurrency runtime. That is the axis.

The benchmark is intentionally shaped as an overhead measurement. It is *not* a demonstration
that language X is a better fit for concurrent workloads; it tells you how expensive the
machinery is in instruction terms.

## The algorithm

A logical ring of `RING_WIDTH = 32` workers (ids `0..31`) is driven by a main controller for
`n` full laps. A 32-bit token `v` is threaded through every worker on each lap via the
language's cooperative messaging primitive. No shared mutable state: the token is the only
communication channel.

```
RING_WIDTH = 32
SEED       = 12345
MOD        = 1_000_000_007

worker(id):
    receive token v
    v = (v * 1103515245 + (id + 1))  mod 2^32   -- deterministic transform
    forward v to next worker (or back to main if id == RING_WIDTH-1)
    repeat for each lap

main:
    v = SEED
    for lap in 1..n:
        send v to worker 0
        receive v from worker 31
    print v mod MOD          -- line 1: checksum
    print n * RING_WIDTH     -- line 2: total hops (secondary)
```

The transform `v = (v * 1103515245 + (id + 1)) mod 2^32` is the standard glibc-style LCG
constant (the same one used by `sort-search`, `polymorphism`, and others in this suite). Each
worker uses its own addend `id + 1` (1..32), ensuring worker 0 is non-trivial and all 32
workers produce distinct transformations.

**Correctness invariant** (Python reference, `/tmp/message_ring_ref.py`):

| n | checksum (line 1) | secondary (line 2) |
|---|--:|--:|
| 500 | `559682169` | `16000` |
| 2000 | `988175140` | `64000` |

Because the token passes through every worker in strict id order, the final value is
fully determined by `n`, `RING_WIDTH`, `SEED`, and the transform constants. No
scheduler ordering can alter it. The checksum is therefore identical in every correct
implementation regardless of runtime, concurrency model, or OS scheduling.

## Why `RING_WIDTH = 32` and not 16

The Go/Elixir feasibility probes used width 16. Width 32 is chosen for two reasons:

1. **Exercises the scheduler more per lap.** A wider ring means more context switches per
   lap without increasing n. This keeps n moderate while giving a richer per-lap signal.
2. **Amortizes spawn/teardown more aggressively.** The differential `I(n2) - I(n1)` cancels
   both runtime startup *and* the one-time cost of spawning 32 workers (those happen once
   regardless of n). A wider ring makes the per-lap steady-state work larger relative to any
   residual noise. Width 32 stays comfortably under the MAX_CPUS=8 slot constraint (the 32
   workers are cooperative / green and all run on the same OS thread; see below).

Width 64 was considered and rejected: at that width the per-lap work starts to become large
enough that n could be reduced to sizes where startup noise re-emerges at the high end.
Width 32 hits the sweet spot between signal and noise.

## Determinism requirement

Every implementation MUST multiplex all 32 workers onto a **single OS scheduler thread**
(or equivalent single-threaded cooperative loop). This is non-negotiable for two reasons:

1. **Correctness**: the token visits workers in order 0, 1, ..., 31, 0, ... only if the
   send/receive handoffs are sequenced. A multi-threaded free-for-all would produce
   nondeterministic token values, failing the checksum gate.
2. **Measurement validity**: on multiple OS threads the qemu plugin's per-vCPU slots can
   alias (see MAX_CPUS constraint below), producing nondeterministic instruction counts.

"Single scheduler thread" means: all 32 workers and the main goroutine / fiber / process are
multiplexed onto one OS-level thread, switching cooperatively on each send/receive. No
busy-wait polling; the hop cost must be real concurrency-primitive overhead.

## MAX_CPUS = 8 plugin constraint

The vendored qemu TCG `insn` plugin (`languages/_base/qemu-plugin/insn.c`) maintains
per-vCPU counters in `counts[cpu_index % 8]` with non-atomic increments. With more than 8
instruction-executing OS threads the slots alias and race, producing nondeterministic
instruction counts (observed ~9% noise at 16 OS threads in probes).

**Every implementation must stay at or below 8 total OS threads** (workers + GC + I/O
threads combined). The determinism pinning for each language achieves this:

- Go: `GOMAXPROCS=1` (single scheduler thread, typically 3-4 OS threads total including
  the network poller and GC). Confirmed clean at 0.001-0.002% jitter in probes.
- Elixir/BEAM: `+S 1:1` (one scheduler, one dirty-scheduler). BEAM uses exactly 8 OS
  threads at this setting (1 scheduler + 1 dirty-CPU + 1 dirty-IO + signal handler +
  others). This sits at the ceiling. Jitter observed at 0.026-0.031% in probes -- within
  tolerance but worth monitoring. If CI shows elevated jitter, the plugin's MAX_CPUS must
  be raised to 16 (a harness change out of scope for this spec).
- JVM (Kotlin/Scala virtual threads): the JVM's carrier-thread pool plus GC threads may
  exceed 8 OS threads. Virtual-thread implementations MUST pin the carrier pool to 1 thread
  (`ForkJoinPool` parallelism=1) and verify OS thread count stays <= 8. If it cannot, the
  cell is flagged and the plugin MAX_CPUS must be raised before it can be measured reliably.
- All other cooperative primitives (Python asyncio, Ruby Fiber, PHP Fiber, C# single-thread
  async, C ucontext, Swift async on a serial executor): stay on 1 OS thread by construction.

## Fairness rules

1. **Use the language's idiomatic cooperative primitive** for the send/receive handoff. No
   OS-thread-per-worker (that measures OS scheduling overhead and hits the plugin ceiling).
   No busy-wait / spin polling. The handoff must suspend the sender until the receiver is
   ready, and vice versa.
2. **No shortcutting the handoff.** The per-hop transform MUST happen inside the worker
   unit (goroutine / fiber / process / coroutine), not in a shared array that main reads
   back. The point is to count the round-trip instruction cost of the actual send+switch+
   transform+switch+receive cycle. Any implementation that folds the transform into main
   (avoiding the context switch) is rejected.
3. **Fixed RING_WIDTH = 32 workers** spawned once before the lap loop. Spawning and
   tearing down workers per lap would measure spawn cost, not hop cost. Workers run for the
   full n laps and then exit.
4. **Exact token arithmetic**: `v = (v * 1103515245 + (id + 1)) mod 2^32`, with `id` being
   the 0-indexed worker position in the ring (0..31). The addend is `id + 1`, not `id`.
   32-bit unsigned wrap: mask `& 0xFFFFFFFF` or use a native `uint32` type.
5. **All integer**. No floating point. No I/O inside the lap loop (print only at the end).
6. The checksum `v mod MOD` (MOD = 10^9+7) is printed on line 1; `n * RING_WIDTH` is
   printed on line 2 as the secondary. Both gates must pass.

## Per-language fairness table

| Language | Cooperative primitive | Determinism pinning | Notes |
|---|---|---|---|
| **C** | `ucontext_t` / `swapcontext` (POSIX, glibc bookworm) | 1 OS thread by construction | Hand-rolled ring of 32 `ucontext_t` coroutines. `swapcontext` is the only sanctioned cooperative-yield primitive in C without a library. `makecontext` + `swapcontext` are available on glibc 2.36 (bookworm) and provide the faithful baseline. Each worker stack ~64KB. |
| **Go** | goroutines + unbuffered channels | `GOMAXPROCS=1` `GODEBUG=asyncpreemptoff=1` (GC on, default `GOGC=100`) | The prototype measured clean at 0.001-0.002% jitter. `asyncpreemptoff=1` prevents the signal-based preemption timer from interrupting a channel-blocked goroutine mid-count. |
| **Rust** | Hand-rolled single-threaded executor polling 32 `impl Future` state machines (std only) | one poll-loop thread by construction | The lang-lab Rust image compiles a bare `rustc -O` single file with no crates available (no `tokio`/`async-std`/`context`) and defaults to edition 2015, so no `async`/`await` syntax. Workers are explicit `Future` state machines handed off through one-slot `Cell` rendezvous channels; each `Poll::Pending` is the cooperative switch. No OS thread per worker. |
| **Swift** | `async`/`await` on a serial `TaskGroup` (Swift Concurrency) | `DispatchQueue(label:, attributes: [])` as executor, or `withTaskGroup` on a serial actor | Swift's concurrency runtime defaults to a thread pool; must be pinned to a single-thread executor. Alternatively, hand-rolled continuation passing with `CheckedContinuation`. |
| **Python** | `asyncio` coroutines + `asyncio.Queue` | default event loop (already single-threaded) | `asyncio.Queue(maxsize=1)` for the handoff channel. No `threading` or `multiprocessing`. |
| **Kotlin** | JVM virtual threads (Project Loom, JDK 21+) with a 1-carrier-thread pool | `Executors.newVirtualThreadPerTaskExecutor()` pinned to 1 carrier: `ForkJoinPool(1)` | Must verify OS thread count stays <= 8. Alternatively: Kotlin coroutines with `Dispatchers.Unconfined` + `Channel(0)` on a single-threaded dispatcher. |
| **Scala** | JVM virtual threads (Loom) or ZIO fibers on a single-thread executor | Same carrier pinning as Kotlin | Same MAX_CPUS caveat as Kotlin. Scala 3 + `scala.concurrent.ExecutionContext.fromExecutorService(Executors.newSingleThreadExecutor())`. |
| **C#** | `async`/`await` with a `SynchronizationContext` on a single thread | `new SingleThreadSynchronizationContext()` or `AsyncPump` pattern | .NET's default `ThreadPool` must NOT be used directly (it spawns multiple threads). The ring must run entirely on one thread's message loop. |
| **Elixir** | BEAM processes + `send`/`receive` | `+S 1:1` (one scheduler) in `runtimeEnv` | Sits at the MAX_CPUS=8 ceiling (BEAM uses exactly 8 OS threads at `+S 1:1`). Measured clean at 0.026-0.031% jitter in probes. Monitor CI for degradation. |
| **PHP** | Fibers (PHP 8.1+) | single-threaded by construction (no PHP threading model) | `Fiber::suspend()` / `Fiber::resume($value)` for the handoff. Requires PHP >= 8.1. No `parallel` extension. |
| **Ruby** | `Fiber` (MRI cooperative fibers) | single-threaded by construction (GIL ensures no true parallelism) | `Fiber.new { |v| loop { v = Fiber.yield(transform(v)) } }`. MRI Fibers are cooperative and do not spawn OS threads. |
| **Perl** | **N/A -- no fair option exists** | -- | Perl has no core cooperative fiber / green-thread primitive. `ithreads` are OS threads (violates the single-OS-thread rule and hits the plugin ceiling). CPAN modules like `Coro` exist but are not present in the lang-lab Perl image. **This cell is N/A**: Perl does not participate in this benchmark. Document in results as "no cooperative primitive in core". |

### C baseline rationale

C participates via POSIX `ucontext_t` / `swapcontext`. This is the standard mechanism for
user-space coroutines on glibc systems (available since glibc 2.0, present on bookworm).
Each worker is a coroutine with its own stack. Main calls `swapcontext` to yield to worker 0,
each worker calls `swapcontext` to yield to the next, and worker 31 yields back to main. This
is the lowest-level faithful analogue of a cooperative handoff in C, with no library hiding
the cost. The C = 1.0x baseline thus measures the raw `swapcontext` instruction cost per hop.

Note: `ucontext_t` is POSIX-deprecated in the POSIX.1-2008 standard but remains fully
functional on glibc bookworm. The lang-lab C image is glibc 2.36 on Debian bookworm;
`_XOPEN_SOURCE=700` or `#define _GNU_SOURCE` enables it.

### Perl coverage call

**Perl**: Perl's concurrency model has no cooperative green-thread primitive in core. `ithreads`
spawn real OS threads (each with its own interpreter state), which violates the single-OS-thread
requirement and would hit the plugin ceiling. The CPAN `Coro` module provides cooperative
coroutines but is not part of the lang-lab Perl image and adding it would mean measuring a
library, not the language runtime. This is a documented N/A gap, not a fairness failure: the
benchmark measures a language axis that Perl simply does not have in its core. Perl has N/A in
the results column.

## Sizes

`n1 = 500`, `n2 = 2000` laps (RING_WIDTH = 32 fixed). The differential
`I(2000) - I(500)` isolates the marginal 48,000 hop-handoffs (1500 laps x 32 workers),
cancelling both runtime startup and the one-time cost of spawning 32 workers.

Expected instruction magnitudes (from probes):
- Go: ~71M differential instructions (~1481 insns/hop x 48000 hops)
- Elixir: ~192M differential instructions (~4000 insns/hop x 48000 hops)

These are in the same range as existing benchmarks (tak's differential is ~49M for C), so
the harness's adaptive RUNS logic and the checksum gate will behave normally.

## Results: uniform qemu+insn pass

Perl does not participate (no cooperative primitive in core), so 13 languages are compared
(Java via virtual threads + `SynchronousQueue`, JavaScript via a single-slot Promise channel on
the event loop).

> **Read the wall-clock table first.** This benchmark reports two metrics that disagree sharply, and
> the disagreement is the point. The **instruction count** (qemu+insn, reproducible) measures how
> much *user-space machinery* a handoff runs, but it is **blind to syscall cost**, which biases it
> heavily toward syscall-based context switches. The **wall-clock per hop** is the honest measure of
> "how fast is a handoff," and it tells a very different story.

### Wall-clock per hop (the honest concurrency metric; normalized to C; lower is better)

Native (no qemu), single OS thread, differential of two sizes (cancels startup), min of reps,
normalized to C. A ratio, so machine speed cancels; NOT bit-reproducible (treat as approximate,
about ±15%). Measured 2026-06-24; data in
[`results/2026-06-24-arm64-message-ring-wall.json`](../../results/2026-06-24-arm64-message-ring-wall.json).

| Language | us/hop | vs C |
|---|--:|--:|
| **Rust** | 0.004 | **0.02×** |
| **Go** | 0.102 | **0.49×** |
| **PHP** | 0.116 | **0.56×** |
| **Ruby** | 0.168 | **0.81×** |
| **C** | 0.207 | **1.00×** |
| C# | 0.218 | 1.05× |
| Elixir | 0.280 | 1.35× |
| Kotlin | 1.43 | 6.89× |
| Scala | 1.43 | 6.91× |
| Python | 2.14 | 10.30× |
| Swift | 41.8 | 201× |

![message-ring wall-clock per hop](../../docs/charts/message-ring-wall.svg)

**Go, PHP and Ruby beat C**, and Elixir and C# are on par, even though all have far higher
instruction counts (below). The reason: C's `swapcontext` does ~2 `rt_sigprocmask` syscalls per hop
(132,032 in a 2000-lap run) that the instruction metric cannot see, while Go and the BEAM do every
handoff in user space (Go: 192 syscalls in an entire run). The user-space scheduling that makes
goroutines and BEAM fast is exactly what inflates their instruction count. Swift is the outlier: its
`@MainActor` continuation hops route through libdispatch (~40us/hop).

### Instruction count per hop (machinery weight, NOT latency; reproducible but syscall-blind)

The differential `I(2000) - I(500)` (qemu+insn, bit-exact) cancels startup plus the one-time spawn of
32 workers, isolating the 48,000 hop-handoffs (1500 laps x 32). C (hand-rolled `ucontext`/`swapcontext`)
is the reference floor. Read this as user-space machinery weight, not speed. Raw data in
[`results/2026-06-23-arm64-message-ring.json`](../../results/2026-06-23-arm64-message-ring.json).

![message-ring differential work](../../docs/charts/message-ring-diff-ratio.svg)

| Language | I(500) | I(2k) | differential | **vs C** (lower is better) | determinism |
|---|--:|--:|--:|--:|---|
| Rust | 724.5k | 2.4M | 1.7M | **0.28×** | exact |
| **C** | 2.1M | 8.0M | 5.9M | **1.00×** | exact |
| PHP | 50.7M | 97.4M | 46.8M | 7.88× | exact |
| Go | 23.2M | 91.7M | 68.5M | 11.54× | jitter |
| Ruby | 314.7M | 425.2M | 110.5M | 18.62× | jitter |
| JavaScript | 181.8M | 339.7M | 157.9M | 26.60× | jitter |
| Elixir | 2.03B | 2.20B | 177.1M | 29.83× | jitter |
| C# | 388.5M | 597.9M | 209.4M | 35.28× | jitter |
| Java | 1.20B | 1.49B | 289.1M | 48.70× | jitter |
| Swift | 115.5M | 425.5M | 310.0M | 52.23× | jitter |
| Scala | 1.34B | 1.67B | 327.3M | 55.15× | jitter |
| Kotlin | 842.8M | 1.20B | 353.7M | 59.59× | jitter |
| Python | 779.2M | 2.39B | 1.61B | 271.54× | jitter |

## Reproduce

```bash
BENCH=message-ring scripts/bench-local.sh <lang>
python3 scripts/make_charts.py results/<date>-<isa>-message-ring.json
```
