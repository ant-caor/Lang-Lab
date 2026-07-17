# Metric validity: what the instruction count does and does not capture

lang-lab's headline metric is the differential guest-instruction count `I(n2) - I(n1)`, normalized
to C. This document **measures**, empirically, how valid that metric is, instead of asserting it.
The short version: it is a strong predictor of relative wall-clock for compute-bound work and is
ISA-robust for native and interpreter runtimes, but its magnitude is only approximate, it is not
ISA-robust for JIT (JVM) runtimes, and it actively misleads when a syscall sits on the critical
path. Read it as "user-space instruction work," a proxy for algorithmic efficiency, not as
wall-clock speed.

## Summary

| Question | Answer |
|---|---|
| Does it predict wall-clock *order*? | Yes. Spearman rank 0.87 across 55 cells; near-perfect for non-JIT. |
| Does it predict wall-clock *magnitude*? | Approximately. R² 0.91 (log-log, compute-bound); typical error ~1.3x, p90 ~3x. |
| Is it ISA-robust (arm64 vs x86_64)? | For native + interpreter, yes (within ~10-15%). For JVM, no (ratios roughly double). |
| When does it actively mislead? | Syscall on the critical path (concurrency primitives) and JIT cross-ISA magnitude. |

## Study 1: instruction count vs wall-clock (calibration)

**Method.** Five compute-heavy, syscall-free benchmarks (gemm, sha256, k-means, lz77, mandelbrot)
x 11 languages, measured **both ways on the same machine (arm64)**: the qemu+insn instruction
differential and the native wall-clock differential (min of repetitions, `t(n2) - t(n1)` to cancel
startup). Both normalized to C, correlated in log space.

**Result.** On the 52 cleanly-measurable cells, Pearson(log instr-vs-C, log wall-vs-C) = **0.956
(R² = 0.91)**; Spearman rank = 0.87. Magnitude error (how far the wall-clock ratio sits from the
instruction ratio): **median x1.32, p90 x2.96**, with a long tail. So the metric reliably orders
languages by speed and gets the magnitude right to about a third, but not better.

**Caveat on the calibration itself.** Three JVM cells (k-means/scala, lz77/kotlin, lz77/scala) were
excluded as measurement failures: at the small spec sizes these programs run too fast natively for a
stable wall-clock differential, and JIT warmup swamps the signal (their differential collapsed to
noise). Including them drags R² down to 0.62. That is a limitation of *this calibration setup at
those sizes*, not evidence about the metric, and it is itself an instance of the JIT difficulty
documented in Study 2.

**Where magnitude diverges most (real cells).** FP-heavy interpreters on mandelbrot (Python, Perl,
PHP, Ruby): the instruction count **overstates** the gap by roughly 3x, because C's floating-point
instructions are individually expensive (latency, no pipelining benefit) while the interpreter's
bookkeeping instructions are cheap and pipeline well, so "one instruction" is not the same cost on
each side. The extreme case lives in a separate study: in
[`message-ring`](../benchmarks/message-ring/README.md), a kernel syscall on every hop makes the
instruction count **invert** the wall-clock ranking (Go is 2.3x faster than C in wall-clock but
11.5x "worse" in instructions). See [the concurrency study](concurrency-study.md).

## Study 2: cross-ISA stability (arm64 vs x86_64)

**Method.** For each cell, compare the vs-C instruction ratio on arm64 (local) and x86_64 (CI),
across 18 benchmarks (215 cells with both ISAs present).

**Result.** 37% of cells stay within +/-10% across ISAs, 67% within +/-25%, 84% within +/-50%; the
median shift is 1.005 (no systematic bias). The tail is the story, and it is **the JVM**:

| Language | geomean vs C, arm64 | geomean vs C, x86_64 | ISA-stable? |
|---|--:|--:|---|
| Rust | 1.11 | 1.20 | yes |
| C# | 1.54\* | 1.31 | yes |
| Go | 1.58 | 1.58 | yes |
| Swift | 2.03 | 2.22\* | yes |
| **Scala** | **2.39** | **4.82** | **no (x2)** |
| **Kotlin** | **2.53** | **4.66** | **no (x1.8)** |
| Elixir | 22.3 | 23.1 | yes |
| PHP | 32.2 | 27.4 | yes |
| Ruby | 75.3 | 76.5\* | mostly |
| Python | 103.7 | 113.5 | yes |
| Perl | 145.5 | 130.0 | mostly |

\* The arm64 geomeans for Swift, Ruby and C# are recomputed from the current envelopes: Swift and
Ruby reflect the post-fix tree (Swift tak/fannkuch, commit `2132918`; Ruby k-nucleotide, commit
`0cb2c0f`), and C# now reads **1.54** (its originally recorded 1.38 had drifted from the envelopes;
the cause of that drift is unconfirmed and still pending its own check). Their x86_64 cells still
predate those fixes and will refresh on the next successful x86_64 `benchmark` CI run, after which
the ISA-stability column should be re-derived.

These arm64 geomeans are the **same quantity as the README leaderboard**: both are computed over
the 18 compute axes, with message-ring excluded from the ranking (it is shown in the matrix as an
unranked column). If the two ever disagree, one of them is stale — recompute both from
`results/*-arm64-*.json`.

Worst single cells: gemm/Scala 1.07x -> 7.30x (x6.85), gemm/Kotlin 1.00x -> 6.24x, sort-search and
bigint Scala/Kotlin x3-3.7. The cross-language leaderboard order holds for the ten non-JVM
languages; Scala and Kotlin move several places between ISAs.

**Why.** A JVM program's instruction count is dominated by JIT-generated machine code, which differs
substantially between arm64 and x86_64. The differential cancels startup, but not the per-ISA
difference in what the JIT emits. Native and interpreter runtimes execute the same (or nearly the
same) guest instruction stream on both ISAs, so they are stable.

## What the metric is valid for

- **Within-language regression detection across versions, fixed ISA.** Excellent and deterministic.
  This is the strongest use (the `rustc-perf` use case): "did this runtime version get more or less
  efficient at this kernel."
- **Cross-language rank / algorithmic-efficiency proxy for native and interpreter runtimes.**
  Reliable (rank holds, ISA-robust).
- **A proxy for relative wall-clock on compute-bound work.** Good for order, approximate (~1.3x,
  tail ~3x) for magnitude.

## What it is NOT valid for

- **Absolute or precise relative wall-clock speed.** Use a wall-clock benchmark.
- **Cross-language magnitude for JIT/JVM languages.** ISA-dependent by ~2x; report JVM per-ISA, not
  as a single number.
- **Anything syscall-bound** (concurrency primitives, I/O). The instruction count can invert the
  truth. The [scaling track](scaling-track.md) and the message-ring wall-clock exist for this.

## How to read the master matrix

It shows **user-space instruction work vs C**, a proxy for algorithmic efficiency, not wall-clock
speed. Its geomean/leaderboard is computed over the 18 compute axes: message-ring is shown as a
column but excluded from the ranking, for exactly the syscall-blindness documented above. It is a
reliable rank for the non-JVM languages; treat the **Kotlin/Scala cells as ISA-specific**. For
concurrency, read the scaling track and the message-ring wall-clock, not the instruction number.
