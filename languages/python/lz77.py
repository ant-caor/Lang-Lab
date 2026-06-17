import sys

P = 1000000007
WINDOW = 512
MIN_MATCH = 3
MAX_MATCH = 255
ALPHA = 6


def lcg(s):
    return (s * 1103515245 + 12345) & 0x7FFFFFFF


def lz77(n):
    data = bytearray(n)
    s = 42
    for i in range(n):
        s = lcg(s)
        data[i] = s % ALPHA

    pos = 0
    h = 0
    while pos < n:
        best_len = 0
        best_dist = 0
        start = pos - WINDOW
        if start < 0:
            start = 0
        cand = pos - 1
        while cand >= start:                              # nearest distance first
            l = 0
            while pos + l < n and l < MAX_MATCH and data[cand + l] == data[pos + l]:
                l += 1
            if l > best_len:                              # strict > : closest wins ties
                best_len = l
                best_dist = pos - cand
            cand -= 1
        if best_len >= MIN_MATCH:
            h = (h * 31 + 1) % P
            h = (h * 31 + best_dist) % P
            h = (h * 31 + best_len) % P
            pos += best_len
        else:
            h = (h * 31 + 0) % P
            h = (h * 31 + data[pos]) % P
            pos += 1
    return h


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 24000
    print(lz77(n))
    print("lz77(%d)" % n)
