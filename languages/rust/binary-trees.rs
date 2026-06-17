use std::env;

struct Node {
    left: Option<Box<Node>>,
    right: Option<Box<Node>>,
}

fn make(depth: i32) -> Box<Node> {
    if depth == 0 {
        Box::new(Node { left: None, right: None })
    } else {
        Box::new(Node {
            left: Some(make(depth - 1)),
            right: Some(make(depth - 1)),
        })
    }
}

fn check(node: &Node) -> i64 {
    match &node.left {
        None => 1,
        Some(l) => 1 + check(l) + check(node.right.as_ref().unwrap()),
    }
}

fn run(n: i32) -> i64 {
    let min_depth = 4;
    let max_depth = std::cmp::max(min_depth + 2, n);
    let stretch_depth = max_depth + 1;

    let mut total = check(&make(stretch_depth));
    let long_lived = make(max_depth);

    let mut depth = min_depth;
    while depth <= max_depth {
        let iterations = 1i64 << (max_depth - depth + min_depth);
        let mut s = 0i64;
        for _ in 0..iterations {
            s += check(&make(depth));
        }
        total += s;
        depth += 2;
    }

    total += check(&long_lived);
    total
}

fn main() {
    let n: i32 = env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(10);
    println!("{}", run(n));
    println!("binary-trees({})", n);
}
