import Foundation

// tak: Takeuchi function - the function-call / recursion-overhead axis. Naive triple recursion,
// no memoization, no iterative rewrite. Checksum = total number of calls (identical-recursion
// invariant); secondary = the returned value. Size n -> tak(3n, 2n, n). Pure integer, no memory.

func tak(_ x: Int, _ y: Int, _ z: Int, _ calls: inout Int) -> Int {
    calls += 1
    if y < x {
        let a = tak(x - 1, y, z, &calls)
        let b = tak(y - 1, z, x, &calls)
        let c = tak(z - 1, x, y, &calls)
        return tak(a, b, c, &calls)
    }
    return z
}

let n = CommandLine.arguments.count > 1 ? (Int(CommandLine.arguments[1]) ?? 6) : 6
var calls = 0
let r = tak(3 * n, 2 * n, n, &calls)
print(calls)
print("tak(\(n)) = \(r)")
