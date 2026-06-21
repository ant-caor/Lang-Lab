// gemm: quantized integer matrix-multiply - the dominant ML inference kernel.
// Square matmul of side N (i.e. N x N matrices). Loop order i,k,j (pinned)
// so B is accessed row-sequentially. LCG fills A then B with values 0..127.
// Accumulator is 64-bit; checksum = poly-hash of C row-major mod 1e9+7.
// No BLAS / no library matmul - the explicit triple loop.
use std::env;

const P: i64 = 1000000007;

fn lcg(s: i64) -> i64 {
    (s.wrapping_mul(1103515245).wrapping_add(12345)) & 0x7fffffff
}

fn run(n: usize) -> (i64, i64) {
    let mut a: Vec<i64> = vec![0; n * n];
    let mut b: Vec<i64> = vec![0; n * n];
    let mut c: Vec<i64> = vec![0; n * n];

    let mut s: i64 = 42;
    for i in 0..n * n {
        s = lcg(s);
        a[i] = s % 128;
    }
    for i in 0..n * n {
        s = lcg(s);
        b[i] = s % 128;
    }

    // Pinned loop order i, k, j - B read row-sequentially.
    for i in 0..n {
        for k in 0..n {
            let av = a[i * n + k];
            let kn = k * n;
            let base = i * n;
            for j in 0..n {
                c[base + j] += av * b[kn + j];
            }
        }
    }

    let mut h: i64 = 0;
    for i in 0..n * n {
        h = (h * 31 + c[i] % P) % P;
    }
    let secondary = c[n * n - 1] % P;
    (h, secondary)
}

fn main() {
    let n: usize = env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(256);
    let (h, sec) = run(n);
    println!("{}", h);
    println!("gemm({}) = {}", n, sec);
}
