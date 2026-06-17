// k-nucleotide: count the frequency of every length-K substring (k-mer) of a
// deterministically generated DNA sequence, using a hash map, then reduce the map to
// one order-independent checksum.
//
// This is the associative-container axis of the suite. C has no standard hash map, so
// we hand-roll an open-addressing table with a general string hash (FNV-1a) and linear
// probing - a real hash map, NOT direct-addressing on the small key space (which would
// be an unfair shortcut). Every other language uses its built-in map.
//
// Everything is integer-deterministic (no floating point): the sequence comes from an
// integer LCG, and the checksum is sum over map entries of encode(kmer)*count mod P,
// which is independent of the map's hash function and iteration order.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define K 8
#define P 1000000007L
#define IM 139968
#define IA 3877
#define IC 29573
#define HBITS 18
#define HSIZE (1 << HBITS)
#define HMASK (HSIZE - 1)

static char *gen(int L) {
    char *s = malloc((size_t)L + 1);
    long seed = 42;
    for (int i = 0; i < L; i++) {
        seed = (seed * IA + IC) % IM;
        s[i] = seed < 42000 ? 'A' : seed < 70000 ? 'C' : seed < 98000 ? 'G' : 'T';
    }
    s[L] = '\0';
    return s;
}

static char htkey[HSIZE][K];
static long htcnt[HSIZE];
static int  htused[HSIZE];

static unsigned long fnv(const char *p) {
    unsigned long h = 1469598103934665603UL;
    for (int i = 0; i < K; i++) { h ^= (unsigned char)p[i]; h *= 1099511628211UL; }
    return h;
}

static void add(const char *kmer) {
    unsigned long h = fnv(kmer) & HMASK;
    while (htused[h]) {
        if (memcmp(htkey[h], kmer, K) == 0) { htcnt[h]++; return; }
        h = (h + 1) & HMASK;
    }
    htused[h] = 1;
    memcpy(htkey[h], kmer, K);
    htcnt[h] = 1;
}

int main(int argc, char **argv) {
    int L = argc > 1 ? atoi(argv[1]) : 100000;
    char *s = gen(L);
    for (int i = 0; i + K <= L; i++) add(s + i);
    long acc = 0;
    for (int b = 0; b < HSIZE; b++) {
        if (!htused[b]) continue;
        long e = 0;
        for (int j = 0; j < K; j++) {
            char c = htkey[b][j];
            int code = c == 'A' ? 0 : c == 'C' ? 1 : c == 'G' ? 2 : 3;
            e = e * 4 + code;
        }
        acc = (acc + e * htcnt[b]) % P;
    }
    printf("%ld\n", acc);
    printf("k-nucleotide(%d)\n", L);
    free(s);
    return 0;
}
