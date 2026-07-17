import java.util.HashMap;
import java.util.Map;

class KNucleotide {
    static String gen(int length) {
        char[] s = new char[length];
        long seed = 42L;
        for (int i = 0; i < length; i++) {
            seed = (seed * 3877 + 29573) % 139968;
            s[i] = seed < 42000 ? 'A' : seed < 70000 ? 'C' : seed < 98000 ? 'G' : 'T';
        }
        return new String(s);
    }

    static long kNucleotide(int length) {
        int k = 8;
        long p = 1000000007L;
        String s = gen(length);

        HashMap<String, Integer> map = new HashMap<>();
        int i = 0;
        while (i + k <= length) {
            String kmer = s.substring(i, i + k);
            Integer cur = map.get(kmer);
            map.put(kmer, cur == null ? 1 : cur + 1);
            i++;
        }

        long acc = 0L;
        for (Map.Entry<String, Integer> entry : map.entrySet()) {
            String kmer = entry.getKey();
            int count = entry.getValue();
            long e = 0L;
            for (int ci = 0; ci < kmer.length(); ci++) {
                char ch = kmer.charAt(ci);
                int code = switch (ch) {
                    case 'A' -> 0;
                    case 'C' -> 1;
                    case 'G' -> 2;
                    default -> 3;
                };
                e = e * 4 + code;
            }
            acc = (acc + e * count) % p;
        }
        return acc;
    }

    public static void main(String[] args) {
        int n = args.length > 0 ? Integer.parseInt(args[0]) : 100000;
        System.out.println(kNucleotide(n));
        System.out.println("k-nucleotide(" + n + ")");
    }
}
