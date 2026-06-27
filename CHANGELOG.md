# Changelog

All notable changes to Lang Lab are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Measurement backend** — QEMU user-mode + the TCG `insn` plugin, counting *guest*
  instructions (deterministic on shared CI, unlike wall-clock time). The headline metric is the
  differential `I(n₂) − I(n₁)` normalized to **C = 1.0×** (lower is better), which cancels runtime startup and JIT
  compilation to isolate the algorithm's real work.
- **12 languages + a C baseline**, chosen to cover every backend runtime archetype: C, Rust,
  Swift and COBOL (native), Go (compiled + concurrent GC), Python, Perl, PHP and Ruby
  (interpreters), Kotlin, Scala and C# (VMs with JIT + GC), and Elixir (BEAM).
- **An 18-benchmark suite**, each stressing an orthogonal runtime axis, every implementation
  reproducing a bit-exact reference checksum: fannkuch, binary-trees, mandelbrot, k-nucleotide,
  reverse-complement, sort-search, dijkstra, blur, k-means, sha256, lz77, vm, bigint, tak,
  polymorphism, and the AI/ML axes gemm (quantized int8 matmul), viterbi (HMM/CRF sequence
  decoding) and gbdt (gradient-boosted tree ensemble inference).
- **message-ring benchmark (concurrency overhead)**: an axis measuring the per-handoff instruction
  cost of each language's cooperative message-passing primitive (a 32-worker ring driven for N
  laps), implemented in 11 languages with their idiomatic cooperative primitive (C `ucontext`, Go
  channels, a hand-rolled std `Future` executor in Rust, Swift continuations, Python `asyncio`,
  PHP/Ruby fibers, Kotlin/Scala JVM virtual threads, a single-thread C# synchronization context,
  Elixir BEAM processes). Perl and COBOL are N/A (no cooperative primitive in core). Measured under
  qemu+insn across all 11 and folded into the master comparison matrix (now 19 axes).
- **Concurrency study** (`docs/concurrency-study.md`): a reproducible, cross-track write-up of
  concurrency per language along three axes: primitive cost (wall-clock per hop, with an
  instruction-count view alongside), parallel scalability as wall-clock `T1/TP`, and real-vs-GIL/GVL
  parallelism. Built with no dedicated hardware, explicit about what it cannot measure (latency,
  throughput under load, contention). Documents that the instruction-count view of message-ring is
  blind to syscall cost (which flatters C's syscall-based `swapcontext`): in wall-clock, Go, PHP and
  Ruby beat C at message-passing.
- **Two automated pipelines** on free GitHub-hosted runners: *version-watch* (endoflife.date →
  pull request bumping `versions.lock.json` when a language ships a new version) and *benchmark*
  (a version-pinned Docker image per language → measured results committed to git history).
- **The master comparison matrix** — a log-coloured heatmap of every language × every benchmark —
  as the README hero, plus per-benchmark SVG charts and a versioned result history under
  `results/`.
- **Scaling track (wall-clock parallel speedup)**: a second, complementary measurement track that
  reports the wall-clock speedup `T1/TP` (higher is better) at 1/2/4 cores (compute region only, run natively, no
  qemu) for five embarrassingly-parallel axes (gemm, mandelbrot, blur, k-means, gbdt) across every
  language with a concurrency primitive (all but COBOL), each using its idiomatic real-parallel
  primitive. Unlike the instruction track it is a ratio, not bit-reproducible. Ships with a
  fairness rulebook (`docs/scaling-track.md`), per-language speedup charts, and a dedicated CI
  workflow that refreshes `results/scaling/`.

### Fixed

- **Ruby k-nucleotide** was 1438× C, by far the worst cell in the whole suite, because of an
  implementation bug in its DNA generator: it built the sequence as one `String` object per
  nucleotide (~200k short-lived allocations the size differential could not cancel), not because of
  the hash map the study text blamed. Rebuilt as an in-place mutable buffer, Ruby now measures
  **56× C** on k-nucleotide, in line with the other interpreters (Perl 36×, Elixir 40×, Python 50×);
  the bit-exact checksums are unchanged. The k-nucleotide study narrative, the cross-suite tables,
  the master matrix and the leaderboard were corrected to match.

[Unreleased]: https://github.com/ant-caor/Lang-Lab/commits/main
