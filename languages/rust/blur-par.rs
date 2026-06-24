// blur-par: parallel 2D Gaussian blur for the wall-clock scaling track.
// Invocation: blur-par <cores> <n>
// Output: identical to serial blur at the same n (core-invariant).
//
// Decomposition: per pass, partition output rows into `cores` contiguous bands.
// Each worker reads the full input buffer (including neighbour rows for the 3x3
// stencil) and writes only its output rows.  After each pass all workers join
// (implicit at scope end) before the buffers are swapped — same barrier semantics
// as the serial double-buffer loop.  Border clamping (edge-replication) is
// preserved verbatim from the serial code.
//
// Build:
//   rustc -O languages/rust/blur-par.rs -o /app/blur-par
use std::env;

const P: i64 = 1000000007;
const PASSES: usize = 4;
const K: [i32; 9] = [1, 2, 1, 2, 4, 2, 1, 2, 1];

fn lcg(s: i64) -> i64 {
    (s.wrapping_mul(1103515245).wrapping_add(12345)) & 0x7fffffff
}

fn clampi(x: i32, n: i32) -> i32 {
    if x < 0 { 0 } else if x >= n { n - 1 } else { x }
}

fn blur_band(src: &[i32], dst: &mut [i32], n: usize, row_start: usize, row_end: usize) {
    let ni = n as i32;
    for row in row_start..row_end {
        let local_row = row - row_start;
        for col in 0..n {
            let mut acc: i32 = 0;
            for di in -1i32..=1 {
                let nr = clampi(row as i32 + di, ni) as usize;
                for dj in -1i32..=1 {
                    let nc = clampi(col as i32 + dj, ni) as usize;
                    acc += K[((di + 1) * 3 + (dj + 1)) as usize] * src[nr * n + nc];
                }
            }
            dst[local_row * n + col] = acc / 16;
        }
    }
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

    let cores = cores.max(1).min(n);
    let nn = n * n;

    let mut src = vec![0i32; nn];
    let mut dst = vec![0i32; nn];

    let mut s: i64 = 42;
    for v in src.iter_mut() {
        s = lcg(s);
        *v = (s % 256) as i32;
    }

    // Build floor-division row bands (reused each pass).
    let bands: Vec<(usize, usize)> = (0..cores)
        .map(|w| (w * n / cores, (w + 1) * n / cores))
        .collect();

    let t0 = std::time::Instant::now();
    for _pass in 0..PASSES {
        // Split `dst` into per-band mutable slices.
        let mut band_slices: Vec<*mut [i32]> = Vec::with_capacity(cores);
        {
            let mut remaining: &mut [i32] = &mut dst;
            let mut offset = 0usize;
            for w in 0..cores {
                let (_, end) = bands[w];
                let len = (end - offset) * n;
                let (head, tail) = remaining.split_at_mut(len);
                band_slices.push(head as *mut [i32]);
                remaining = tail;
                offset = end;
            }
        }

        // src is read-only for all workers this pass.
        let src_ref: &[i32] = &src;

        std::thread::scope(|scope| {
            for w in 0..cores {
                let (start, end) = bands[w];
                let ptr = band_slices[w];
                // SAFETY: band_slices[w] is a unique non-overlapping segment of `dst`
                // derived from split_at_mut; no other thread touches it.
                let dst_band: &mut [i32] = unsafe { &mut *ptr };
                scope.spawn(move || {
                    blur_band(src_ref, dst_band, n, start, end);
                });
            }
        });
        // All workers have joined; swap buffers (barrier satisfied by scope end).
        std::mem::swap(&mut src, &mut dst);
    }
    eprintln!("COMPUTE_NS {}", t0.elapsed().as_nanos());

    // Serial checksum over `src` (the final buffer after PASSES swaps).
    let mut h: i64 = 0;
    for v in &src {
        h = (h * 31 + *v as i64) % P;
    }
    println!("{}", h);
    println!("blur({})", n);
}
