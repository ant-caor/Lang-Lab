using System;
using System.Collections.Generic;

class KNucleotide
{
    const int K = 8;
    const long P = 1000000007L;
    const int IM = 139968;
    const int IA = 3877;
    const int IC = 29573;

    static string Gen(int n)
    {
        char[] s = new char[n];
        long seed = 42;
        for (int i = 0; i < n; i++)
        {
            seed = (seed * IA + IC) % IM;
            s[i] = seed < 42000 ? 'A' : seed < 70000 ? 'C' : seed < 98000 ? 'G' : 'T';
        }
        return new string(s);
    }

    static long Run(int n)
    {
        string s = Gen(n);

        // Use GetAlternateLookup (.NET 9) so that the hot-path TryGetValue + index-update
        // operates on a ReadOnlySpan<char> slice of the existing string (zero allocation).
        // Only the first time a k-mer is seen does a string get allocated for the new key.
        // At n=200000 this reduces ~200k string allocations to at most 65536 (4^8 distinct
        // 8-mers), cutting GC pressure dramatically under qemu-x86_64's constrained runner.
        // The dictionary still uses string keys throughout — fairness is preserved.
        var map = new Dictionary<string, long>();
        var lookup = map.GetAlternateLookup<ReadOnlySpan<char>>();
        for (int i = 0; i + K <= n; i++)
        {
            ReadOnlySpan<char> kmer = s.AsSpan(i, K);
            lookup.TryGetValue(kmer, out long c);
            lookup[kmer] = c + 1;
        }

        long acc = 0;
        foreach (var kv in map)
        {
            string kmer = kv.Key;
            long e = 0;
            for (int j = 0; j < K; j++)
            {
                char ch = kmer[j];
                int code = ch == 'A' ? 0 : ch == 'C' ? 1 : ch == 'G' ? 2 : 3;
                e = e * 4 + code;
            }
            acc = (acc + e * kv.Value) % P;
        }
        return acc;
    }

    static void Main(string[] args)
    {
        int n = args.Length > 0 ? int.Parse(args[0]) : 100000;
        Console.WriteLine(Run(n));
        Console.WriteLine($"k-nucleotide({n})");
    }
}
