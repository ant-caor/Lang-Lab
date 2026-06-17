// reverse-complement: generate a DNA sequence, reverse it in place while complementing
// each base (A<->T, C<->G), then reduce it to a polynomial string hash. The reverse uses a
// hand-written two-pointer loop (NOT a stdlib bulk reverse) and the hash a per-character
// loop (NOT a builtin), so this measures the language's own per-character processing -
// consistent with the suite's no-stdlib-shortcut rule. Everything is integer-deterministic.
#include <stdio.h>
#include <stdlib.h>

#define P 1000000007L
#define IM 139968
#define IA 3877
#define IC 29573

static int comp(int c) {            // A<->T, C<->G; only A/C/G/T occur
    return c == 'A' ? 'T' : c == 'C' ? 'G' : c == 'G' ? 'C' : 'A';
}

int main(int argc, char **argv) {
    int L = argc > 1 ? atoi(argv[1]) : 100000;
    char *s = malloc((size_t)L + 1);
    long seed = 42;
    for (int i = 0; i < L; i++) {
        seed = (seed * IA + IC) % IM;
        s[i] = seed < 42000 ? 'A' : seed < 70000 ? 'C' : seed < 98000 ? 'G' : 'T';
    }
    int i = 0, j = L - 1;
    while (i < j) {                  // two-pointer reverse-and-complement, in place
        char a = (char)comp((unsigned char)s[i]);
        s[i] = (char)comp((unsigned char)s[j]);
        s[j] = a;
        i++; j--;
    }
    if (i == j) s[i] = (char)comp((unsigned char)s[i]);
    long h = 0;
    for (int k = 0; k < L; k++) h = (h * 31 + (unsigned char)s[k]) % P;
    printf("%ld\n", h);
    printf("reverse-complement(%d)\n", L);
    free(s);
    return 0;
}
