// bigint: hand-rolled multi-precision arithmetic - the carry-propagation axis. Compute N! as an
// array of base-2^32 limbs by repeated bignum*smallint multiplication (each limb: cur = limb*k +
// carry; store low 32 bits, propagate the high bits), then poly-hash the limbs. Implemented by hand
// (NO native/library big integers - languages with built-in bignum must hand-roll too), so it
// measures raw multi-word arithmetic. All integer-deterministic.
import Foundation

let P: UInt64 = 1000000007

func bigint(_ n: Int) -> UInt64 {
    var limbs = [UInt32](repeating: 0, count: n + 64)
    var len = 1
    limbs[0] = 1
    var k: UInt64 = 2
    while k <= UInt64(n) {
        var carry: UInt64 = 0
        for i in 0..<len {
            let cur = UInt64(limbs[i]) * k + carry
            limbs[i] = UInt32(cur & 0xFFFFFFFF)
            carry = cur >> 32
        }
        while carry > 0 {
            limbs[len] = UInt32(carry & 0xFFFFFFFF)
            len += 1
            carry >>= 32
        }
        k += 1
    }
    var h: UInt64 = 0
    for i in 0..<len {
        h = (h &* 31 &+ UInt64(limbs[i])) % P
    }
    return h
}

let n = CommandLine.arguments.count > 1 ? (Int(CommandLine.arguments[1]) ?? 6000) : 6000
print(bigint(n))
print("bigint(\(n))")
