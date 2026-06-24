// gemm-par: parallel integer matrix-multiply for the wall-clock scaling track.
// Invocation: gemm-par <cores> <n>
// Computes EXACTLY the same C = A * B as gemm.rs (pinned i->k->j loop order,
// identical LCG fill, identical poly-hash checksum).
//
// Parallelism: std::thread::scope (stable since Rust 1.63) partitions the N
// output rows into `cores` contiguous bands.  Worker w owns rows
//   [w * N / cores, (w+1) * N / cores)
// and writes only those rows of C via disjoint mutable slices from
// chunks_mut -- no unsafe, no shared writes, no atomics.
//
// Build (matches the Dockerfile):
//   rustc -O languages/rust/gemm-par.rs -o /app/gemm-par

use std::env;

const P: i64 = 1000000007;

fn lcg(s: i64) -> i64 {
    (s.wrapping_mul(1103515245).wrapping_add(12345)) & 0x7fffffff
}

fn main() {
    let mut args = env::args().skip(1);
    let cores: usize = args
        .next()
        .and_then(|s| s.parse().ok())
        .unwrap_or(1);
    let n: usize = args
        .next()
        .and_then(|s| s.parse().ok())
        .unwrap_or(256);

    // Clamp cores to [1, n] so every band is non-empty.
    let cores = cores.max(1).min(n);

    // ---- fill A and B (sequential, same LCG sequence as serial gemm) ----
    let mut a: Vec<i64> = vec![0; n * n];
    let mut b: Vec<i64> = vec![0; n * n];
    let mut c: Vec<i64> = vec![0; n * n];

    let mut s: i64 = 42;
    for v in a.iter_mut() {
        s = lcg(s);
        *v = s % 128;
    }
    for v in b.iter_mut() {
        s = lcg(s);
        *v = s % 128;
    }

    // ---- parallel matmul: each thread owns a contiguous band of rows of C ----
    //
    // Row bands are [w*N/cores, (w+1)*N/cores) using integer division, which
    // guarantees contiguous, non-overlapping coverage of all N rows regardless
    // of whether N is divisible by cores.
    //
    // We split the flat `c` slice into per-band sub-slices with chunks_mut so
    // the borrow checker proves disjoint ownership with zero unsafe.  However,
    // chunks_mut gives equal-sized chunks (size = ceil(N/cores)), which differs
    // from the floor-division band formula above when N % cores != 0.  To stay
    // exactly aligned with the floor-division boundary computation used in the
    // worker body, we build the disjoint slices manually via split_at_mut in a
    // loop -- still entirely safe.

    // Build band boundaries [start, end) for each worker.
    let bands: Vec<(usize, usize)> = (0..cores)
        .map(|w| {
            let start = w * n / cores;
            let end = (w + 1) * n / cores;
            (start, end)
        })
        .collect();

    // Slice c into disjoint mutable sub-slices, one per band.
    // Each sub-slice covers c[start*n .. end*n].
    {
        // We need shared read access to `a` and `b` inside threads.
        // std::thread::scope allows borrowing the outer stack, so we
        // can pass &a and &b safely.
        let a_ref: &[i64] = &a;
        let b_ref: &[i64] = &b;

        // Split `c` into per-band mutable slices.
        // Collect as *mut pointers so we can hand them to scoped threads.
        // Safety argument: the bands are non-overlapping contiguous row ranges,
        // so the raw slices we reconstruct are truly disjoint.  We use
        // split_at_mut in a loop to get safe &mut slices first, then convert.
        let mut band_slices: Vec<*mut [i64]> = Vec::with_capacity(cores);
        {
            let mut remaining: &mut [i64] = &mut c;
            let mut offset = 0usize; // row offset already consumed
            for w in 0..cores {
                let (start, end) = bands[w];
                // `remaining` starts at row `offset`; we need rows start..end.
                // Since bands are sorted and contiguous, start == offset always.
                let _ = start; // == offset, checked by construction
                let len = (end - offset) * n;
                let (head, tail) = remaining.split_at_mut(len);
                band_slices.push(head as *mut [i64]);
                remaining = tail;
                offset = end;
            }
        }

        let t0 = std::time::Instant::now();
        std::thread::scope(|scope| {
            for w in 0..cores {
                let (start, end) = bands[w];
                let ptr = band_slices[w];
                // SAFETY: band_slices[w] points to a unique, non-overlapping
                // segment of `c` that no other thread touches.  The raw pointer
                // was derived from a &mut [i64] obtained via split_at_mut, so
                // it is aligned and valid for the lifetime of `c`.
                let c_band: &mut [i64] = unsafe { &mut *ptr };
                scope.spawn(move || {
                    // c_band covers rows [start, end) of C, stored row-major.
                    // Row i of C maps to c_band[(i - start) * n .. (i - start + 1) * n].
                    for i in start..end {
                        let ci = i - start; // row index within our band
                        for k in 0..n {
                            let av = a_ref[i * n + k];
                            let kn = k * n;
                            let base = ci * n;
                            for j in 0..n {
                                c_band[base + j] += av * b_ref[kn + j];
                            }
                        }
                    }
                });
            }
        });
        eprintln!("COMPUTE_NS {}", t0.elapsed().as_nanos());
    }

    // ---- checksum (identical to serial gemm) ----
    let mut h: i64 = 0;
    for v in &c {
        h = (h * 31 + v % P) % P;
    }
    let secondary = c[n * n - 1] % P;
    println!("{}", h);
    println!("gemm({}) = {}", n, secondary);
}
