# Changelog

All notable changes to Lang Lab are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Measurement backend** — QEMU user-mode + the TCG `insn` plugin, counting *guest*
  instructions (deterministic on shared CI, unlike wall-clock time). The headline metric is the
  differential `I(n₂) − I(n₁)` normalized to **C = 1.0×**, which cancels runtime startup and JIT
  compilation to isolate the algorithm's real work.
- **12 languages + a C baseline**, chosen to cover every backend runtime archetype: C, Rust,
  Swift and COBOL (native), Go (compiled + concurrent GC), Python, Perl, PHP and Ruby
  (interpreters), Kotlin, Scala and C# (VMs with JIT + GC), and Elixir (BEAM).
- **An 18-benchmark suite**, each stressing an orthogonal runtime axis, every implementation
  reproducing a bit-exact reference checksum: fannkuch, binary-trees, mandelbrot, k-nucleotide,
  reverse-complement, sort-search, dijkstra, blur, k-means, sha256, lz77, vm, bigint, tak,
  polymorphism, and the AI/ML axes gemm (quantized int8 matmul), viterbi (HMM/CRF sequence
  decoding) and gbdt (gradient-boosted tree ensemble inference).
- **Two automated pipelines** on free GitHub-hosted runners: *version-watch* (endoflife.date →
  pull request bumping `versions.lock.json` when a language ships a new version) and *benchmark*
  (a version-pinned Docker image per language → measured results committed to git history).
- **The master comparison matrix** — a log-coloured heatmap of every language × every benchmark —
  as the README hero, plus per-benchmark SVG charts and a versioned result history under
  `results/`.

[Unreleased]: https://github.com/ant-caor/Lang-Lab/commits/main
