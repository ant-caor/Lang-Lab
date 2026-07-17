# Fairness audit: does each cell measure the language, or the implementation?

The most serious critique a cross-language benchmark can face is not "instructions are the wrong
metric" (that one is quantified in [metric-validity.md](metric-validity.md)); it is **"your
implementation of language X is bad, so the cell measures your code, not the language."** With one
author writing every implementation, that critique deserves a process, not a promise. This
document is that process and its results so far.

## Method

1. **Data triage.** Every cell is compared against its archetype peers (interpreters vs
   interpreters, JVM vs CLR, natives vs natives). A cell that deviates by an order of magnitude
   from its peers on one axis, while tracking them on the others, is flagged as a suspected
   implementation artifact rather than a language cost.
2. **Adversarial audit.** Each flagged cell gets a language-expert review whose explicit job is to
   *blame the implementation*: find the allocation, the missed idiom, the accidental O(n²), the
   build flag.
3. **Fairness review.** Any proposed fix is then reviewed by an independent algorithm reviewer
   with the opposite job: reject fixes that would quietly advantage one language over the rest
   (an optimization is only accepted if the same idiom is either available to all peers or is the
   language's genuinely idiomatic form).
4. **The checksum gate holds throughout.** A fix is only a fix if the bit-exact reference
   checksums still pass at both problem sizes.

Every audited case lands in exactly one of three buckets: **cleared** (the number is a real
language cost), **fixed** (implementation bug found, corrected, re-measured), or **rejected fix**
(a proposed optimization that the fairness review vetoed). All three buckets are listed below,
including the embarrassing ones, because a leaderboard is only trustworthy if its corrections are
public.

## Case 1: PHP, cleared

**Suspicion:** PHP runs ~3-5× lighter than Python/Perl/Ruby across the integer axes (for example
sha256: PHP 98× vs Python 601×). Triage hypothesis: the PHP 8 JIT was silently on.

**Finding: refuted.** `opcache.jit=disable` is set, `opcache_get_status()` confirms it, and the
instruction count is identical with and without opcache. PHP's advantage is real interpreter
architecture: typed zvals with native 64-bit integers (Python pays its arbitrary-precision int
machinery on every arithmetic op), plus compile-time constant folding. The archetype label
`interp` is correct and the cells stand.

## Case 2: Ruby k-nucleotide, fixed (the worst cell in the matrix was our bug)

**Suspicion:** Ruby's k-nucleotide sat at **1438× C**, the worst cell in the whole matrix, an
order of magnitude beyond its interpreter peers (Python 50×, Elixir 40×, Perl 36×).

**Finding: implementation bug, not the language.** The DNA generator built the sequence as
~200,000 one-character String objects joined at the end; those short-lived allocations do not
cancel in the size differential and ballooned the count. The study prose at the time blamed
Ruby's hash map. That prose was wrong.

**Fix (commit `0cb2c0f`):** generate into one in-place mutable buffer (4 allocations instead of
200,003). Checksums unchanged. Ruby's cell went from **1438× to 56.4×**, in line with its peers,
and the study narrative, cross-suite tables, matrix and leaderboard were all corrected.

## Case 3: Swift, two fixed, one rejected

**Suspicion:** Swift (a native, ARC language) ran 4-6× C on axes where Rust runs ~1×.

**Finding: about half the gap was fixable source, half is real.** `swiftc -O` keeps bounds,
overflow, exclusivity and CoW checks (it is not C's `-O2`), and the audit deliberately did NOT
switch to `-Ounchecked`, which would be non-idiomatic for production Swift.

- **tak, fixed (commit `2132918`):** a top-level mutable counter forced a `swift_beginAccess`
  exclusivity check on every recursive call; threading it as an `inout` parameter removed it.
  **4.75× to 1.15×.** Checksum unchanged.
- **fannkuch, fixed (same commit):** `withUnsafeMutableBufferPointer` around the flip loop removed
  per-swap CoW/bounds checks. **4.75× to 3.42×**; the residue is the permutation generator's own
  bounds/overflow checks, which idiomatic Swift genuinely pays.
- **k-nucleotide, fix REJECTED:** the proposal (replace the String key with a packed `UInt64`)
  was vetoed by the fairness review, because C#/Kotlin/Scala/Go could equally use an integer key
  and keep String keys; accepting it only for Swift would break the study's cross-language rule.
  Swift's 9.67× **stays** as a genuine cost of its heap-String path.
- **polymorphism 6.4×, cleared:** existential boxing (protocol witness project/destroy per
  dispatch) is how idiomatic Swift dynamic dispatch works; there is no fair source-level fix.

## Case 4: the flattering outliers, cleared

The audit also triaged the cells that look *too good*: C#/Elixir/Scala/Kotlin beating C on
binary-trees (0.28-0.45×). Finding: expected and real. A generational/bump allocator amortizes
allocation in ways `malloc`/`free` cannot; that is the axis working as designed, not a bug.

## Standing corrections

- The arm64 leaderboard reflects all fixes above. x86_64 cells refresh on the next green CI run.
- Superseded numbers are never silently edited: fixes land as commits with the old and new values
  stated (see `0cb2c0f`, `2132918`, and the [CHANGELOG](../CHANGELOG.md)).

## Challenge us

If your language looks unfairly slow, the strongest possible response is a pull request:

1. Change only `languages/<lang>/<benchmark>.<ext>`.
2. Keep the algorithm within the study's fairness rules (each `benchmarks/<bench>/README.md`
   states them; no library shortcuts where the suite hand-rolls).
3. The bit-exact checksums must still pass at both sizes (`scripts/bench-fast.sh <lang>` gates
   this locally).

A PR that meets those three rules and lowers a cell is a finding, and it will be merged and
credited. That is how Ruby's worst cell got fixed; the process works.
