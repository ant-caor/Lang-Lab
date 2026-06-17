import sys

P = 1000000007
IM = 139968
IA = 3877
IC = 29573


def comp(c):  # A<->T, C<->G; only A/C/G/T occur
    if c == 65:  # 'A'
        return 84  # 'T'
    if c == 67:  # 'C'
        return 71  # 'G'
    if c == 71:  # 'G'
        return 67  # 'C'
    return 65  # 'A'


def reverse_complement(L):
    s = bytearray(L)
    seed = 42
    for i in range(L):
        seed = (seed * IA + IC) % IM
        if seed < 42000:
            s[i] = 65  # 'A'
        elif seed < 70000:
            s[i] = 67  # 'C'
        elif seed < 98000:
            s[i] = 71  # 'G'
        else:
            s[i] = 84  # 'T'

    i = 0
    j = L - 1
    while i < j:  # two-pointer reverse-and-complement, in place
        a = comp(s[i])
        s[i] = comp(s[j])
        s[j] = a
        i += 1
        j -= 1
    if i == j:
        s[i] = comp(s[i])  # middle char when L is odd

    h = 0
    for k in range(L):
        h = (h * 31 + s[k]) % P
    return h


if __name__ == "__main__":
    L = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
    print(reverse_complement(L))
    print("reverse-complement(%d)" % L)
