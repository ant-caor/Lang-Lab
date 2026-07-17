class Fannkuch {
    static int[] fannkuch(int n) {
        int[] perm1 = new int[n];
        for (int i = 0; i < n; i++) perm1[i] = i;
        int[] perm = new int[n];
        int[] count = new int[n];
        int maxFlips = 0;
        int checksum = 0;
        long permIdx = 0L;  // counts up to n!-1 -> needs 64-bit for n >= 13
        int r = n;

        while (true) {
            while (r != 1) {
                count[r - 1] = r;
                r--;
            }

            System.arraycopy(perm1, 0, perm, 0, n);
            int flips = 0;
            int k = perm[0];
            while (k != 0) {
                int i = 0, j = k;
                while (i < j) {
                    int t = perm[i]; perm[i] = perm[j]; perm[j] = t;
                    i++; j--;
                }
                flips++;
                k = perm[0];
            }

            if (flips > maxFlips) maxFlips = flips;
            checksum += (permIdx % 2 == 0L) ? flips : -flips;

            // Generate the next permutation.
            while (true) {
                if (r == n) return new int[]{maxFlips, checksum};
                int first = perm1[0];
                for (int i = 0; i < r; i++) perm1[i] = perm1[i + 1];
                perm1[r] = first;
                count[r]--;
                if (count[r] > 0) break;
                r++;
            }
            permIdx++;
        }
    }

    public static void main(String[] args) {
        int n = args.length > 0 ? Integer.parseInt(args[0]) : 7;
        int[] res = fannkuch(n);
        System.out.println(res[1]);
        System.out.println("Pfannkuchen(" + n + ") = " + res[0]);
    }
}
