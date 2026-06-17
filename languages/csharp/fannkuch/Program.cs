using System;

class Fannkuch
{
    static (int, int) Run(int n)
    {
        var perm1 = new int[n];
        for (int x = 0; x < n; x++) perm1[x] = x;
        var perm = new int[n];
        var count = new int[n];
        int maxFlips = 0, checksum = 0, r = n;
        long permIdx = 0;  // counts up to n!-1 → needs 64-bit for n >= 13

        while (true)
        {
            while (r != 1) { count[r - 1] = r; r--; }

            Array.Copy(perm1, perm, n);
            int flips = 0;
            int k = perm[0];
            while (k != 0)
            {
                int i = 0, j = k;
                while (i < j) { int t = perm[i]; perm[i] = perm[j]; perm[j] = t; i++; j--; }
                flips++;
                k = perm[0];
            }

            if (flips > maxFlips) maxFlips = flips;
            checksum += (permIdx % 2 == 0) ? flips : -flips;

            // Generate the next permutation.
            while (true)
            {
                if (r == n) return (maxFlips, checksum);
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

    static void Main(string[] args)
    {
        int n = args.Length > 0 ? int.Parse(args[0]) : 7;
        var (maxFlips, checksum) = Run(n);
        Console.WriteLine(checksum);
        Console.WriteLine($"Pfannkuchen({n}) = {maxFlips}");
    }
}
