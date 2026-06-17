import sys

K = 8
P = 1000000007
IM = 139968
IA = 3877
IC = 29573

CODE = {"A": 0, "C": 1, "G": 2, "T": 3}


def gen(length):
    seed = 42
    chars = []
    for _ in range(length):
        seed = (seed * IA + IC) % IM
        if seed < 42000:
            chars.append("A")
        elif seed < 70000:
            chars.append("C")
        elif seed < 98000:
            chars.append("G")
        else:
            chars.append("T")
    return "".join(chars)


def k_nucleotide(length):
    s = gen(length)

    counts = {}
    for i in range(length - K + 1):
        kmer = s[i:i + K]
        counts[kmer] = counts.get(kmer, 0) + 1

    acc = 0
    for kmer, count in counts.items():
        e = 0
        for ch in kmer:
            e = e * 4 + CODE[ch]
        acc = (acc + e * count) % P
    return acc


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
    print(k_nucleotide(n))
    print("k-nucleotide(%d)" % n)
