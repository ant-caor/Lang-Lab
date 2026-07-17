// bigint: hand-rolled multi-precision arithmetic - the carry-propagation axis. Compute N! as an
// array of base-2^32 limbs by repeated bignum*smallint multiplication (each limb: cur = limb*k +
// carry; store low 32 bits, propagate the high bits), then poly-hash the limbs. Implemented by hand
// (NO native/library big integers - no java.math.BigInteger), so it measures raw multi-word
// arithmetic. All integer-deterministic. int[] holds 32-bit limbs; a limb is read back as unsigned
// via `& 0xFFFFFFFFL`, and cur = limb*k + carry uses a 64-bit long intermediate.

class Bigint {
    static final long P = 1000000007L;

    static long bigint(int n) {
        int[] limbs = new int[n + 64];   // base 2^32, least-significant limb first
        limbs[0] = 1;
        int len = 1;
        for (int k = 2; k <= n; k++) {
            long carry = 0L;   // 64-bit carry
            for (int i = 0; i < len; i++) {
                long cur = (limbs[i] & 0xFFFFFFFFL) * (long) k + carry;   // ~2^46, fits in long
                limbs[i] = (int) (cur & 0xFFFFFFFFL);   // low 32 bits
                carry = cur >>> 32;   // high bits propagate
            }
            while (carry > 0L) {
                limbs[len++] = (int) (carry & 0xFFFFFFFFL);
                carry = carry >>> 32;
            }
        }
        long h = 0L;
        for (int i = 0; i < len; i++) h = (h * 31 + (limbs[i] & 0xFFFFFFFFL)) % P;   // poly-hash, LSL first
        return h;
    }

    public static void main(String[] args) {
        int n = args.length > 0 ? Integer.parseInt(args[0]) : 6000;
        System.out.println(bigint(n));
        System.out.println("bigint(" + n + ")");
    }
}
