// reverse-complement: generate a DNA sequence, reverse it in place while complementing
// each base (A<->T, C<->G), then reduce it to a polynomial string hash. The reverse uses a
// hand-written two-pointer loop (NOT a stdlib bulk reverse) and the hash a per-character
// loop (NOT a builtin), so this measures the language's own per-character processing -
// consistent with the suite's no-stdlib-shortcut rule. Everything is integer-deterministic.

class ReverseComplement {
    static final long P = 1000000007L;
    static final long IM = 139968L;
    static final long IA = 3877L;
    static final long IC = 29573L;

    static char comp(char c) {   // A<->T, C<->G; only A/C/G/T occur
        return c == 'A' ? 'T' : c == 'C' ? 'G' : c == 'G' ? 'C' : 'A';
    }

    static long reverseComplement(int l) {
        char[] s = new char[l];   // mutable char buffer
        long seed = 42L;
        for (int k = 0; k < l; k++) {
            seed = (seed * IA + IC) % IM;
            s[k] = seed < 42000 ? 'A' : seed < 70000 ? 'C' : seed < 98000 ? 'G' : 'T';
        }
        int i = 0, j = l - 1;
        while (i < j) {   // two-pointer reverse-and-complement, in place
            char a = comp(s[i]);
            s[i] = comp(s[j]);
            s[j] = a;
            i++;
            j--;
        }
        if (i == j) s[i] = comp(s[i]);   // middle char when L is odd
        long h = 0L;
        for (int k = 0; k < l; k++) {
            h = (h * 31 + (long) s[k]) % P;   // s[k] is the ASCII/char code
        }
        return h;
    }

    public static void main(String[] args) {
        int l = args.length > 0 ? Integer.parseInt(args[0]) : 100000;
        System.out.println(reverseComplement(l));
        System.out.println("reverse-complement(" + l + ")");
    }
}
