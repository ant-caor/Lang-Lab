#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void fannkuch(int n, int *max_flips_out, int *checksum_out) {
    int *perm1 = malloc(n * sizeof(int));
    int *perm = malloc(n * sizeof(int));
    int *count = malloc(n * sizeof(int));
    for (int i = 0; i < n; i++) perm1[i] = i;

    int max_flips = 0, checksum = 0, r = n;
    long perm_idx = 0;  /* counts up to n!-1 → needs 64-bit for n >= 13 */
    for (;;) {
        while (r != 1) { count[r - 1] = r; r--; }

        memcpy(perm, perm1, n * sizeof(int));
        int flips = 0, k;
        while ((k = perm[0]) != 0) {
            for (int i = 0, j = k; i < j; i++, j--) {
                int t = perm[i]; perm[i] = perm[j]; perm[j] = t;
            }
            flips++;
        }

        if (flips > max_flips) max_flips = flips;
        checksum += (perm_idx % 2 == 0) ? flips : -flips;

        /* Generate the next permutation. */
        for (;;) {
            if (r == n) {
                *max_flips_out = max_flips; *checksum_out = checksum;
                free(perm1); free(perm); free(count);
                return;
            }
            int first = perm1[0];
            for (int i = 0; i < r; i++) perm1[i] = perm1[i + 1];
            perm1[r] = first;
            if (--count[r] > 0) break;
            r++;
        }
        perm_idx++;
    }
}

int main(int argc, char **argv) {
    int n = argc > 1 ? atoi(argv[1]) : 7;
    int max_flips, checksum;
    fannkuch(n, &max_flips, &checksum);
    printf("%d\n", checksum);
    printf("Pfannkuchen(%d) = %d\n", n, max_flips);
    return 0;
}
