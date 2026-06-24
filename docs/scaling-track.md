# Scaling Track: Fairness Rulebook

Wall-clock parallel-speedup track for lang-lab. This document is the single authoritative
source for what is and is not fair when implementing or measuring a parallel variant.

---

## 1. What the scaling track measures and why it differs from the instruction track

The instruction track (qemu+insn) counts guest instructions and reports a ratio normalized
to C = 1.0x. That metric is deliberately single-threaded, deterministic, and ISA-pinned.

The scaling track answers a different question: **given a benchmark whose algorithm is
parallelizable, how well does each language let you use multiple cores?** The metric is
the wall-clock speedup ratio T1/TP (minimum wall time at 1 core divided by minimum wall
time at P cores), where both T1 and TP are measured in the same native run (no qemu); **higher is
better**, with the ideal being P (perfect linear scaling).
Taking a ratio cancels machine-speed noise; validated to +/-0.03 on a 4-core cap on
free CI runners.

The instruction track cannot answer this question correctly. The qemu TCG insn plugin
sums guest instructions across all cores, so a GIL-bound Python program that uses 4
threads accumulates ~4x the instructions of the 1-thread run even though wall time is
unchanged. That produces a false 4x "speedup" in instructions. Wall clock exposes the
truth. The two tracks are complementary; neither replaces the other.

The scaling track result is NOT bit-exact (wall time varies); report speedup values to
three decimal places with the understanding that +/-0.03 is the noise floor.

---

## 2. Invocation contract

```
<program> <cores> <n>
```

- `argv[1]` = integer core count P (1, 2, or 4).
- `argv[2]` = problem size N (same values as the serial benchmark).
- Output: exactly 2 lines, identical to the serial benchmark's output at the same N.
  Line 1: checksum (`sum`). Line 2: secondary line.
- The harness (`scripts/measure-scaling.sh`) injects `{P}` into the run-command template
  for the core count and appends the size. The run-command must contain the literal `{P}`
  placeholder.

---

## 3. Core-invariance: the correctness invariant

**The parallel result (both output lines) MUST be bit-for-bit identical for cores=1, 2,
and 4, and MUST equal the serial result.**

This is not a soft requirement. It is the mechanism that lets the scaling track reuse the
serial `spec.json` checksums as its correctness gate without maintaining a separate set of
expected outputs. The harness verifies the checksum at every core count before timing.

Why this is achievable: for all parallelizable axes in this suite the work decomposes into
independent sub-problems whose partial results are combined by an associative reduction
(addition for gemm accumulators, a final poly-hash pass over an already-complete array).
The decomposition must be chosen so that the final state of the output array is identical
regardless of P.

Implications for implementation:
- The output array must be written in a deterministic order. Parallel workers each write
  a disjoint partition; the checksum pass runs serially over the full array in the same
  row-major order as the serial benchmark. Do not hash inside worker threads.
- No floating-point reduction across threads (the suite is all-integer; this is already
  satisfied by the integer constraint, but worth stating explicitly here).
- No randomness seeded from thread ID, core count, or wall time.

---

## 4. True-parallel-primitive rule

The parallel primitive used must actually achieve parallel execution on the target runtime.
Using a primitive that serializes execution (e.g., Python threads under the GIL, Ruby
threads under the GVL) counts as a GIL/GVL variant, not a real parallel entry.

Rules by language category:

**No-GIL languages** (C, Rust, Go, Swift, Kotlin, Scala, C#, Elixir, PHP, Perl in native
mode): use the language's idiomatic thread primitive.

- C: `pthreads` (`pthread_create` / `pthread_join`).
- Rust: `std::thread::scope` from the standard library only. No `rayon`, no `tokio`.
  The reason is availability risk: crates are not in the Docker images and adding them
  requires Dockerfile edits, whereas `std::thread::scope` (stable since Rust 1.63) is
  always present.
- Go: goroutines + `sync.WaitGroup`. The Go scheduler is already parallel; GOMAXPROCS
  must be set to the core count argument (not left at the default) so that P=1 actually
  runs on 1 thread.
- Swift: `DispatchQueue` concurrent or `TaskGroup` (async/await). Either is acceptable;
  the implementation must not use more OS threads than the core count argument.
- Kotlin / Scala: `java.util.concurrent` thread pool sized to the core count. No
  `kotlinx.coroutines` or Akka unless they are already present in the image.
- C#: `Parallel.For` or `Task`-per-band with degree-of-parallelism limited to core count.
- PHP: `parallel\Runtime` (the `parallel` extension). If not present in the image, fall
  back to process-per-band via `pcntl_fork`.
- Perl: `threads` module. The Perl `threads` module uses real POSIX threads; the GIL
  note below does not apply.

**GIL/GVL languages** (CPython, MRI Ruby):

These runtimes serialize CPU work across threads. The only fair CPU-parallel primitive is
**processes** (subprocess/fork). The primary scaling-track entry uses processes. An
optional secondary entry using threads MAY be added to demonstrate the GIL, with
`PRIMITIVE=threads` in the harness output and a clear label in results ("GIL-bound").

- Python: `multiprocessing.Pool` sized to the core count. Workers run in separate
  processes; communicate results back via shared memory (`multiprocessing.Array`) or
  `Queue`. The threads variant uses `threading.Thread` and will show speedup ~1.0x.
- Ruby: `Process.fork` per band, with a pipe or shared-memory mechanism to return
  partial results. The threads variant uses `Thread` and will show speedup ~1.0x under
  the GVL.

**Elixir**: BEAM processes are the natural parallel unit. Use `Task.async` / `Task.await`
with one Task per band, or a direct `spawn` + `receive` pattern. BEAM is truly parallel
across schedulers; set `+S P:P` (schedulers = P) via the existing `runtimeEnv` mechanism.

---

## 5. Forbidden shortcuts

The following optimizations change the algorithm (not just parallelism) and are not
permitted in the scaling-track variants. The same rules as the serial track apply.

- No BLAS, numpy, or any library that performs the matrix multiply (gemm).
- No stdlib sort or bsearch (sort-search).
- No stdlib hash map that does the counting work (k-nucleotide).
- No algorithmic change to the loop structure (e.g., do not reorder loops from i,k,j
  to something else because it would be more cache-friendly under parallelism).
- No speculative parallelism that produces a different result when workers race
  (e.g., lock-free accumulation without proper synchronization is forbidden even if it
  produces the right answer on a particular run).
- No padding or replication of shared data to improve cache behavior beyond what a
  per-language idiomatic parallel implementation would naturally do. Acceptable: each
  worker maintains a private accumulator row; unacceptable: artificially inflate array
  stride to a cache-line multiple.

---

## 6. Load balance and partition rule

Workers must receive approximately equal work. For row-band decompositions:

- Worker w (0-indexed) handles rows `[w*N/cores, (w+1)*N/cores)` using integer floor
  division. This distributes rows as evenly as possible across workers, differing by at
  most 1 row when N is not divisible by cores.
- The partition must be contiguous (row-bands, not interleaved rows). Interleaved
  partitions would produce better cache behavior for some access patterns and worse for
  others, introducing a variable that differs across languages without being a language
  property.

Biasing the partition to make one core count look better than another is a fairness
violation.

---

## 7. No shared-write contention

Workers must write to disjoint memory regions. Specifically:

- Each worker writes only its own output rows. No worker reads or writes rows belonging
  to another worker.
- The checksum and secondary value are computed in a single-threaded pass after all
  workers have completed, iterating over the output array in the same order as the serial
  benchmark.
- Atomic operations, mutexes, or lock-free structures used to coordinate work assignment
  or result collection are permitted only in the coordination layer (e.g., a queue of
  pending band indices); they must never be used on the critical path of the compute loop
  itself.

---

## 8. Per-benchmark parallelizability classification

### 8a. Embarrassingly-parallel map: parallelize

These benchmarks decompose into independent units of work with no inter-unit dependency.
The parallel variant is straightforward and produces a real parallel speedup.

**gemm** (see Section 9 for the exact decomposition). The N output rows of C are
independent. Inner-loop access pattern is unchanged (i,k,j pinned). Expected speedup: P
for native runtimes.

**mandelbrot**: each pixel is independent. Decompose the NxN grid into P horizontal
bands of N/P rows. Each worker iterates its rows, writes to its band of the output
buffer, and the final checksum pass runs serially. The FMA-contraction-proof formula
(`t=zr*zi; zi=t+t+ci`) must be preserved in the parallel variant. Auto-vectorization
remains permitted.

**blur**: each output pixel depends only on a 3x3 neighbourhood in the input pass. For
multi-pass double-buffered blur, the parallelism applies per pass: divide the NxN image
into P horizontal bands, each worker computes its band of the output buffer from the
input buffer, then buffers are swapped for the next pass. Border clamping must be
consistent with the serial specification (edge-replication). No worker writes to rows
outside its band.

**k-means** (ITERS=10, K=16, D=4): the assignment step (nearest centroid by squared
distance for each of N points) is embarrassingly parallel -- divide points into P bands.
The centroid update step (sum coordinates of assigned points, divide by count) requires
a reduce-and-broadcast between the assignment and update phases. Each iteration
completes the parallel assignment, then a serial reduce updates centroids, then the next
iteration begins. The lowest-index tie-break rule (`strict <`) must be preserved
identically -- workers must not reorder points within their band.

**gbdt** (B=200 trees, N samples): the B tree evaluations per sample are independent of
each other (all trees read the same static tree arrays, no write). Divide the N samples
into P bands; each worker evaluates all B trees for its samples and accumulates a sum
per sample. Final checksum pass runs serially. No writes to the tree arrays.

### 8b. Map-reduce: parallelize with a serial reduction phase

**k-nucleotide**: the K-mer counting pass can be parallelized by dividing the sequence
into P bands (with a K-1 overlap at each boundary to avoid missing k-mers that span the
partition point -- this overlap is critical for correctness). Each worker builds a
private count map for its band. After all workers complete, the P private maps are merged
into a single map by summing counts for matching keys. The checksum is then computed from
the merged map in the same way as the serial benchmark.

The overlap rule: worker w processes positions `[w*L/P - (K-1), (w+1)*L/P)` clamped to
[0, L). The leading (K-1) positions of each band (except the first) are overlap only:
they contribute to k-mers that cross the boundary. Without this overlap the counts are
wrong and the checksum will not match.

**reverse-complement**: the reversal is an in-place two-pointer swap -- inherently serial
(each swap involves one element from the left half and one from the right). However the
buffer can be divided into P non-overlapping pairs: worker w handles positions
`[w*N/(2*P), (w+1)*N/(2*P))` from the left paired with the corresponding mirror positions
from the right. No two workers touch the same position. The complement mapping (A<->T,
C<->G) applies within each swap. The polynomial hash over the final buffer is computed
serially. This decomposition is correct and core-invariant.

### 8c. Parallel sort: decompose with merge

**sort-search**: the N integers can be sorted in parallel using a parallel merge sort or
a sample-sort approach. However the hand-written median-of-three Hoare quicksort must be
the sort kernel used in each sub-problem -- parallel implementations may not substitute
a different sort algorithm. A compliant approach: divide the N elements into P bands,
each worker sorts its band with the hand-written quicksort, then a serial merge
(hand-written) produces the final sorted array. The binary-search phase is embarrassingly
parallel (N independent queries, divide across P workers, serial hash reduction). This
is substantially more complex than the embarrassingly-parallel axes; weigh the
implementation cost against the insight gained.

### 8d. Inherently sequential: document as ~1.0x, do NOT reimplement

These benchmarks have loop-carried dependencies that make true parallelism impossible
without changing the algorithm. Implementing a parallel version would require a different
algorithm, violating the core-invariance and same-algorithm rules. The correct
scaling-track entry for these benchmarks is to document them as inherently sequential and
report speedup = 1.0x at all core counts.

**viterbi**: the forward trellis has a hard sequential dependency -- step t requires the
full viterbi vector from step t-1. There is no cross-step parallelism. The backtrace is
also sequential (pointer chain). A "parallel" variant would need wavefront DP across
independent sequences, which is a different workload.

**sha256 (iterative)**: N rounds of SHA-256 are chained -- the output digest of round k
is the input to round k+1. No two rounds can execute in parallel. Parallelism would
require hashing N independent messages, which is a different benchmark.

**bigint (N! limb accumulation)**: each multiplication step `cur = limb * k + carry`
requires the carry from the previous step. The limb array grows monotonically and each
step extends the current result. No parallelism without restructuring as a parallel
prefix product, which changes the algorithm.

**vm (bytecode interpreter)**: the VM executes a single-threaded instruction stream with
a loop-carried accumulator. The loop-carried `acc` state makes it sequential by design.
Parallelism would require running independent VM instances, which is a different
workload.

**lz77 (greedy parse)**: the greedy parse is sequential -- the position of each token
depends on the output length of the previous token. Parallel LZ variants (like block
decomposition with independent windows) use a different algorithm and produce different
output.

**dijkstra**: Dijkstra's algorithm is a priority-queue sequential process -- each step
relaxes neighbors of the current minimum-distance node, and the minimum can only be
known after all previous relaxations. Parallel graph algorithms (Bellman-Ford, delta
stepping) are different algorithms. The hand-written binary min-heap requirement rules
out concurrent heap variants.

### 8e. Scaling-track value is limited: note and defer

**fannkuch**: the permutation enumeration is a sequential count. Parallelism is possible
(partition the permutation space) but the workload is so small (n1=7, n2=9) that
startup+fork overhead dominates at N=9 and the result is noise.

**binary-trees**: the benchmark's defining axis is GC allocation behavior. Parallel
allocation introduces GC concurrency effects that are runtime-specific, not
language-algorithm properties. The scaling speedup would measure GC parallelism more
than algorithm parallelism. Defer until the scaling track has a dedicated GC axis.

**tak**: pure recursion with no memory traffic. Each recursive call is independent, but
the call tree is enormous and task-spawning overhead for fine-grained tasks dominates any
benefit. The benchmark exists to measure function-call overhead; parallelizing it
measures task-system overhead instead.

**polymorphism**: the N*M dispatch loop has a loop-carried accumulator (each
`obj.apply(acc)` feeds the next). The accumulator cannot be decoupled without changing
the benchmark's defining property (that the checksum depends on M, preventing hoisting).

---

## 9. gemm row-band decomposition: canonical specification

This section specifies the exact parallel decomposition for gemm to ensure all language
experts implement the same variant.

### Decomposition

Partition the N output rows of matrix C into `cores` contiguous bands.

Worker w (0-indexed, w in 0..cores-1) computes rows:

```
row_start = w * N / cores        (integer floor division)
row_end   = (w + 1) * N / cores  (exclusive; last worker gets row_end = N)
```

Each worker executes the same triple-nested loop as the serial benchmark, restricted to
its row range:

```
for i in row_start..row_end-1:
    for k in 0..N-1:
        a = A[i*N + k]
        for j in 0..N-1:
            C[i*N + j] += a * B[k*N + j]
```

Key properties:
- Loop order i->k->j is unchanged. This is mandatory (serial fairness rule 2).
- Worker w reads all of A (rows row_start..row_end only), all of B (all rows, read-only),
  and writes C rows row_start..row_end only. No two workers write to the same element.
- B is read-only and shared. All workers reading B concurrently is safe.
- A is read-only. Workers read disjoint rows of A but read access is not exclusive.
- C is zero-initialized before workers start (same as serial `calloc`).

### Checksum pass

After all workers have joined, the main thread computes the checksum and secondary value
in a single serial pass, identical to the serial benchmark:

```
h = 0
for idx in 0..N*N-1:
    h = (h*31 + C[idx] % P) % P
secondary = C[N*N-1] % P
print h
print "gemm(N) = secondary"
```

This ordering is core-invariant: C[idx] is written by exactly one worker in the same
sequence as the serial loop, and the hash is computed over the completed array.

### Core-invariance proof sketch

For each element C[i*N+j], the value is:

```
sum over k in 0..N-1 of A[i*N+k] * B[k*N+j]
```

This value does not depend on which worker computed it or how many workers there are.
The worker that owns row i computes all N values of k for that row in order, same as the
serial code. The final C array is therefore bit-identical to the serial result for any
core count that evenly divides N (128 and 256 are both divisible by 1, 2, and 4).

For core counts that do not evenly divide N, the floor-division band rule assigns an
extra row to some workers. The C values are still computed identically; only the
boundary rows shift. The checksum output is still identical because C itself is
identical.

### Audit verdict

The row-band decomposition as specified is:
- Canonical: it is the natural embarrassingly-parallel decomposition of a matrix-multiply
  output. Each output row is independent; the i->k->j access pattern means each worker
  streams through its rows of A and all of B in the same order as serial code.
- Fair: no loop-order change, no algorithmic shortcut, no BLAS.
- Core-invariant: proven above. The output C array is identical for any P dividing N,
  and the checksum is computed serially from C, so it must match the serial spec.json
  values (n=128: 151580209/341376, n=256: 586643040/682752).
- Load-balanced: rows are distributed as evenly as integer floor-division allows. For
  N=256, cores=4: each worker gets exactly 64 rows. For N=128, cores=4: 32 rows each.
  For cores=2: 128/64 rows each respectively. Perfect balance at all specified sizes.

No corrections required to the proposed decomposition.

---

## 10. Output and reporting

The `measure-scaling.sh` harness emits one JSON line per (language, benchmark) run:

```json
{
  "language": "...",
  "benchmark": "...",
  "version": "...",
  "track": "scaling",
  "metric": "wallclock-speedup",
  "primitive": "threads|processes",
  "size": N,
  "reps": 5,
  "min_seconds": {"1": ..., "2": ..., "4": ...},
  "speedup": {"1": 1.000, "2": ..., "4": ...},
  "correct": true
}
```

For GIL/GVL languages that have both a processes entry and a threads entry, emit two
JSON lines with `"primitive": "processes"` and `"primitive": "threads"` respectively.
The processes entry is the primary result; the threads entry is labeled "GIL-bound" in
display.

Speedup values near 1.0x for GIL-bound thread entries confirm that the scaling track is
measuring correctly (they are not a bug).

---

## 11. Summary: which benchmarks to implement first

Priority 1 (clean embarrassing-parallel, high expected speedup, worth the implementation
effort):

1. gemm -- row-band decomposition, canonical and proven above.
2. mandelbrot -- pixel-independent, row-band.
3. blur -- row-band per pass, high arithmetic intensity.
4. gbdt -- sample-band, static tree, no write contention.
5. k-means -- point-band for assignment + serial centroid reduce.

Priority 2 (parallelizable but more complex or limited insight):

6. k-nucleotide -- map-reduce with K-1 overlap boundary correction.
7. reverse-complement -- disjoint pointer-pair bands.
8. sort-search -- parallel sort requires careful merge; lower priority.

Do not parallelize (document as sequential ~1.0x):

- viterbi, sha256, bigint, vm, lz77, dijkstra.

Defer (scaling insight is limited or noise-dominated):

- fannkuch, binary-trees, tak, polymorphism.
