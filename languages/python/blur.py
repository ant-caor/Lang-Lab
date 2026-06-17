import sys

P = 1000000007
PASSES = 4
K = (1, 2, 1, 2, 4, 2, 1, 2, 1)  # 3x3, sum 16


def clampi(x, n):
    return 0 if x < 0 else (n - 1 if x >= n else x)


def blur(n):
    src = [0] * (n * n)
    dst = [0] * (n * n)

    s = 42
    for k in range(n * n):
        s = (s * 1103515245 + 12345) & 0x7FFFFFFF
        src[k] = s % 256

    for _ in range(PASSES):
        for i in range(n):
            for j in range(n):
                acc = 0
                for di in (-1, 0, 1):
                    ni = clampi(i + di, n)
                    for dj in (-1, 0, 1):
                        nj = clampi(j + dj, n)
                        acc += K[(di + 1) * 3 + (dj + 1)] * src[ni * n + nj]
                dst[i * n + j] = acc // 16  # integer division
        src, dst = dst, src  # double-buffer swap

    h = 0
    for k in range(n * n):
        h = (h * 31 + src[k]) % P
    return h


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 256
    print(blur(n))
    print("blur(%d)" % n)
