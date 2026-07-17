// sha256: iterated SHA-256 - the bit-manipulation / cryptography axis of the suite. Start from
// a 32-byte LCG-generated digest and apply real FIPS 180-4 SHA-256 to it N times (each hash is a
// single padded block). The hot path is rotations, XOR, shifts and modular 2^32 addition - work
// no other benchmark does. Hand-written (no crypto library); the checksum is a poly-hash of the
// final 32-byte digest. Java int is 32-bit and wraps; right shifts MUST be >>> (logical).

class Sha256 {
    static final long P = 1000000007L;

    static final int[] K = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    };

    static final int[] H0 = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    };

    static int rotr(int x, int n) { return (x >>> n) | (x << (32 - n)); }

    static void sha256Block(byte[] b, int[] h) {
        int[] w = new int[64];
        for (int i = 0; i < 16; i++) {
            w[i] = ((b[i * 4] & 0xff) << 24) |
                   ((b[i * 4 + 1] & 0xff) << 16) |
                   ((b[i * 4 + 2] & 0xff) << 8) |
                   (b[i * 4 + 3] & 0xff);
        }
        for (int i = 16; i < 64; i++) {
            int s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
            int s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
            w[i] = w[i - 16] + s0 + w[i - 7] + s1;
        }
        int a = h[0], bb = h[1], c = h[2], d = h[3];
        int e = h[4], f = h[5], g = h[6], hh = h[7];
        for (int i = 0; i < 64; i++) {
            int s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
            int ch = (e & f) ^ (~e & g);
            int t1 = hh + s1 + ch + K[i] + w[i];
            int s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
            int maj = (a & bb) ^ (a & c) ^ (bb & c);
            int t2 = s0 + maj;
            hh = g; g = f; f = e; e = d + t1; d = c; c = bb; bb = a; a = t1 + t2;
        }
        h[0] += a; h[1] += bb; h[2] += c; h[3] += d;
        h[4] += e; h[5] += f; h[6] += g; h[7] += hh;
    }

    // hash the 32-byte digest in place (one padded 64-byte block; message length = 256 bits)
    static void sha256_32(byte[] digest) {
        byte[] b = new byte[64];
        System.arraycopy(digest, 0, b, 0, 32);
        b[32] = (byte) 0x80;
        for (int i = 33; i < 64; i++) b[i] = 0;
        b[62] = 1;   // length 256 = 0x0100
        int[] h = new int[8];
        System.arraycopy(H0, 0, h, 0, 8);
        sha256Block(b, h);
        for (int i = 0; i < 8; i++) {
            digest[i * 4] = (byte) (h[i] >>> 24);
            digest[i * 4 + 1] = (byte) (h[i] >>> 16);
            digest[i * 4 + 2] = (byte) (h[i] >>> 8);
            digest[i * 4 + 3] = (byte) h[i];
        }
    }

    public static void main(String[] args) {
        int n = args.length > 0 ? Integer.parseInt(args[0]) : 10000;
        byte[] d = new byte[32];
        long s = 42L;
        for (int i = 0; i < 32; i++) {
            s = (s * 1103515245L + 12345L) & 0x7fffffffL;
            d[i] = (byte) (s % 256);
        }
        for (int i = 0; i < n; i++) sha256_32(d);
        long h = 0L;
        for (int i = 0; i < 32; i++) h = (h * 31 + (d[i] & 0xff)) % P;
        System.out.println(h);
        System.out.println("sha256(" + n + ")");
    }
}
