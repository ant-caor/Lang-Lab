// sort-search: generate N integers, sort them with a hand-written median-of-three
// quicksort (Hoare partition), then run N binary searches and fold the found indices
// into a checksum. The two classic algorithms - quicksort and binary search - written
// out explicitly (no stdlib sort/binary_search), so this measures the LANGUAGE executing
// the SAME algorithm, consistent with the suite's no-stdlib-shortcut rule. All integer.
use std::env;

const P: i64 = 1000000007;

fn lcg_next(s: i64) -> i64 {
    (s.wrapping_mul(1103515245).wrapping_add(12345)) & 0x7fffffff
}

// median-of-three + Hoare partition, recurse both sides; depth stays ~log N.
fn qsort_h(a: &mut [i64], lo: i64, hi: i64) {
    if lo >= hi {
        return;
    }
    let mid = lo + (hi - lo) / 2;
    if a[mid as usize] < a[lo as usize] {
        a.swap(lo as usize, mid as usize);
    }
    if a[hi as usize] < a[lo as usize] {
        a.swap(lo as usize, hi as usize);
    }
    if a[hi as usize] < a[mid as usize] {
        a.swap(mid as usize, hi as usize);
    }
    let pivot = a[mid as usize];
    let mut i = lo - 1;
    let mut j = hi + 1;
    loop {
        loop {
            i += 1;
            if a[i as usize] >= pivot {
                break;
            }
        }
        loop {
            j -= 1;
            if a[j as usize] <= pivot {
                break;
            }
        }
        if i >= j {
            break;
        }
        a.swap(i as usize, j as usize);
    }
    qsort_h(a, lo, j);
    qsort_h(a, j + 1, hi);
}

fn bsearch_i(a: &[i64], n: i64, key: i64) -> i64 {
    let mut lo: i64 = 0;
    let mut hi: i64 = n - 1;
    while lo <= hi {
        let mid = lo + (hi - lo) / 2;
        if a[mid as usize] < key {
            lo = mid + 1;
        } else if a[mid as usize] > key {
            hi = mid - 1;
        } else {
            return mid;
        }
    }
    -1
}

fn run(n: i64) -> i64 {
    let mut a: Vec<i64> = vec![0; n as usize];
    let mut state: i64 = 42;
    for i in 0..n as usize {
        state = lcg_next(state);
        a[i] = state;
    }
    qsort_h(&mut a, 0, n - 1);
    let mut h: i64 = 0;
    for _ in 0..n {
        state = lcg_next(state);
        let key = a[(state % n) as usize]; // a value present in the sorted array -> a hit
        let idx = bsearch_i(&a, n, key);
        h = (h * 31 + (idx + 1)) % P;
    }
    h
}

fn main() {
    let n: i64 = env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(100000);
    println!("{}", run(n));
    println!("sort-search({})", n);
}
