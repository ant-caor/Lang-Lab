import sys

P = 1000000007
MASK = 0xFFFFFFFF


def bigint(n):
    limbs = [1]  # least-significant limb first; base 2^32
    length = 1
    for k in range(2, n + 1):
        carry = 0
        for i in range(length):
            cur = limbs[i] * k + carry  # 64-bit-range intermediate (~2^46 here)
            limbs[i] = cur & MASK  # low 32 bits
            carry = cur >> 32  # high bits propagate
        while carry > 0:
            limbs.append(carry & MASK)
            length += 1
            carry >>= 32
    h = 0
    for limb in limbs:  # poly-hash, least-significant first
        h = (h * 31 + limb) % P
    return h


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 6000
    print(bigint(n))
    print("bigint(%d)" % n)
