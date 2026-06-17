use std::env;

fn fannkuch(n: usize) -> (i32, i32) {
    let mut perm1: Vec<usize> = (0..n).collect();
    let mut perm = vec![0usize; n];
    let mut count = vec![0usize; n];
    let mut max_flips = 0i32;
    let mut checksum = 0i32;
    let mut perm_idx = 0i64;
    let mut r = n;

    loop {
        while r != 1 {
            count[r - 1] = r;
            r -= 1;
        }

        perm.copy_from_slice(&perm1);
        let mut flips = 0i32;
        let mut k = perm[0];
        while k != 0 {
            let (mut i, mut j) = (0usize, k);
            while i < j {
                perm.swap(i, j);
                i += 1;
                j -= 1;
            }
            flips += 1;
            k = perm[0];
        }

        if flips > max_flips {
            max_flips = flips;
        }
        if perm_idx % 2 == 0 {
            checksum += flips;
        } else {
            checksum -= flips;
        }

        // Generate the next permutation.
        loop {
            if r == n {
                return (max_flips, checksum);
            }
            let first = perm1[0];
            for i in 0..r {
                perm1[i] = perm1[i + 1];
            }
            perm1[r] = first;
            count[r] -= 1;
            if count[r] > 0 {
                break;
            }
            r += 1;
        }
        perm_idx += 1;
    }
}

fn main() {
    let n: usize = env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(7);
    let (max_flips, checksum) = fannkuch(n);
    println!("{}", checksum);
    println!("Pfannkuchen({}) = {}", n, max_flips);
}
