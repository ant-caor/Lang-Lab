import Foundation

// tak: Takeuchi function - the function-call / recursion-overhead axis. Naive triple recursion,
// no memoization, no iterative rewrite. Checksum = total number of calls (identical-recursion
// invariant); secondary = the returned value. Size n -> tak(3n, 2n, n). Pure integer, no memory.
var calls = 0

func tak(_ x: Int, _ y: Int, _ z: Int) -> Int {
    calls += 1
    if y < x {
        return tak(tak(x - 1, y, z), tak(y - 1, z, x), tak(z - 1, x, y))
    }
    return z
}

let n = CommandLine.arguments.count > 1 ? (Int(CommandLine.arguments[1]) ?? 6) : 6
let r = tak(3 * n, 2 * n, n)
print(calls)
print("tak(\(n)) = \(r)")
