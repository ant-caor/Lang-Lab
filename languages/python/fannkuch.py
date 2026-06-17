import sys


def fannkuch(n):
    perm1 = list(range(n))
    count = [0] * n
    max_flips = 0
    checksum = 0
    perm_idx = 0
    r = n
    while True:
        while r != 1:
            count[r - 1] = r
            r -= 1

        perm = perm1[:]
        flips = 0
        k = perm[0]
        while k:
            i, j = 0, k
            while i < j:
                perm[i], perm[j] = perm[j], perm[i]
                i += 1
                j -= 1
            flips += 1
            k = perm[0]

        if flips > max_flips:
            max_flips = flips
        checksum += flips if perm_idx % 2 == 0 else -flips

        # Generate the next permutation.
        while True:
            if r == n:
                return max_flips, checksum
            first = perm1[0]
            perm1[:r] = perm1[1 : r + 1]
            perm1[r] = first
            count[r] -= 1
            if count[r] > 0:
                break
            r += 1
        perm_idx += 1


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 7
    max_flips, checksum = fannkuch(n)
    print(checksum)
    print("Pfannkuchen(%d) = %d" % (n, max_flips))
