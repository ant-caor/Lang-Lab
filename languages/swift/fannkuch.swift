import Foundation

func fannkuch(_ n: Int) -> (Int, Int) {
    var perm1 = Array(0..<n)
    var perm = Array(repeating: 0, count: n)
    var count = Array(repeating: 0, count: n)
    var maxFlips = 0
    var checksum = 0
    var permIdx = 0
    var r = n

    while true {
        while r != 1 {
            count[r - 1] = r
            r -= 1
        }

        perm = perm1
        var flips = 0
        perm.withUnsafeMutableBufferPointer { buf in
            var k = buf[0]
            while k != 0 {
                var i = 0
                var j = k
                while i < j {
                    let tmp = buf[i]
                    buf[i] = buf[j]
                    buf[j] = tmp
                    i += 1
                    j -= 1
                }
                flips += 1
                k = buf[0]
            }
        }

        if flips > maxFlips {
            maxFlips = flips
        }
        checksum += (permIdx % 2 == 0) ? flips : -flips

        // Generate the next permutation.
        while true {
            if r == n {
                return (maxFlips, checksum)
            }
            let first = perm1[0]
            for i in 0..<r {
                perm1[i] = perm1[i + 1]
            }
            perm1[r] = first
            count[r] -= 1
            if count[r] > 0 {
                break
            }
            r += 1
        }
        permIdx += 1
    }
}

let n = CommandLine.arguments.count > 1 ? (Int(CommandLine.arguments[1]) ?? 7) : 7
let (maxFlips, checksum) = fannkuch(n)
print(checksum)
print("Pfannkuchen(\(n)) = \(maxFlips)")
