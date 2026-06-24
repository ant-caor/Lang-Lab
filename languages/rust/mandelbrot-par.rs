// mandelbrot-par: parallel Mandelbrot for the wall-clock scaling track.
// Invocation: mandelbrot-par <cores> <n>
// Output: identical to serial mandelbrot at the same n (core-invariant).
//
// Decomposition: partition the N rows of the NxN grid into `cores` contiguous
// bands.  Worker w owns rows [w*N/cores, (w+1)*N/cores) and writes a per-row
// count into a disjoint sub-slice of a flat output buffer.  After all workers
// join, the main thread sums the row counts for the final checksum.
//
// The FMA-contraction-proof formula (t=zr*zi; zi=t+t+ci) is preserved verbatim.
// Auto-vectorization remains permitted (same rule as serial).
//
// Build:
//   rustc -O languages/rust/mandelbrot-par.rs -o /app/mandelbrot-par
use std::env;

fn mandel_row(y: i32, n: i32) -> i64 {
    let ci = 2.0 * y as f64 / n as f64 - 1.0;
    let mut count: i64 = 0;
    for x in 0..n {
        let cr = 2.0 * x as f64 / n as f64 - 1.5;
        let mut zr: f64 = 0.0;
        let mut zi: f64 = 0.0;
        let mut tr: f64 = 0.0;
        let mut ti: f64 = 0.0;
        let mut i = 0;
        while i < 50 && tr + ti <= 4.0 {
            let t = zr * zi;
            zi = t + t + ci; // 2*zr*zi + ci, FMA-proof
            zr = tr - ti + cr;
            tr = zr * zr;
            ti = zi * zi;
            i += 1;
        }
        if tr + ti <= 4.0 {
            count += 1;
        }
    }
    count
}

fn main() {
    let mut args = env::args().skip(1);
    let cores: usize = args
        .next()
        .and_then(|s| s.parse().ok())
        .unwrap_or(1);
    let n: i32 = args
        .next()
        .and_then(|s| s.parse().ok())
        .unwrap_or(128);

    let cores = cores.max(1).min(n as usize);
    let nn = n as usize;

    // One i64 per row; workers write disjoint sub-slices.
    let mut row_counts: Vec<i64> = vec![0i64; nn];

    // Build floor-division row bands.
    let bands: Vec<(usize, usize)> = (0..cores)
        .map(|w| (w * nn / cores, (w + 1) * nn / cores))
        .collect();

    // Split row_counts into per-band mutable slices via split_at_mut.
    let mut band_slices: Vec<*mut [i64]> = Vec::with_capacity(cores);
    {
        let mut remaining: &mut [i64] = &mut row_counts;
        let mut offset = 0usize;
        for w in 0..cores {
            let (_, end) = bands[w];
            let len = end - offset;
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
            // SAFETY: band_slices[w] is a unique, non-overlapping segment of
            // row_counts derived from split_at_mut.  No other thread touches it.
            let slice: &mut [i64] = unsafe { &mut *ptr };
            scope.spawn(move || {
                for row in start..end {
                    slice[row - start] = mandel_row(row as i32, n);
                }
            });
        }
    });
    eprintln!("COMPUTE_NS {}", t0.elapsed().as_nanos());

    // Serial reduction: sum row counts (same value as counting in serial order).
    let count: i64 = row_counts.iter().sum();

    println!("{}", count);
    println!("mandelbrot({})", n);
}
