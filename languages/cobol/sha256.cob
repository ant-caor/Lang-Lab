>>SOURCE FORMAT FREE
*> sha256: iterated real FIPS 180-4 SHA-256 - the bit-manipulation / crypto axis.
*> Faithful port of languages/c/sha256.c. COBOL has no native bit ops, so unsigned
*> 32-bit XOR / AND / OR / NOT, logical right shift and rotate are emulated by hand:
*> shifts are multiply/divide by 2^k masked with FUNCTION MOD(x,4294967296); XOR/AND/OR
*> are computed bit-by-bit over 32 bits. Modular 2^32 addition via MOD. A very HIGH
*> instruction count is EXPECTED and correct (COBOL lacks fixed-width bit types).
*> Output: line 1 = poly-hash checksum of the final 32-byte digest, line 2 = sha256(n).
*> Native ELF via cobc -> bit-exact under qemu+insn.
IDENTIFICATION DIVISION.
PROGRAM-ID. sha256.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            PIC S9(9)  COMP-5 VALUE 10000.
01 WS-ARG          PIC X(16)         VALUE SPACES.

*> 2^32 modulus for unsigned 32-bit wraparound
01 WS-MOD32        PIC S9(18) COMP-5 VALUE 4294967296.

*> SHA-256 round constants K[64]
01 KTAB-T.
   05 KK          PIC S9(18) COMP-5 OCCURS 64 TIMES.

*> initial hash values H0[8]
01 H0-T.
   05 HH0         PIC S9(18) COMP-5 OCCURS 8 TIMES.

*> message schedule w[64]
01 WTAB-T.
   05 WW          PIC S9(18) COMP-5 OCCURS 64 TIMES.

*> working hash h[8]
01 HASH-T.
   05 HV          PIC S9(18) COMP-5 OCCURS 8 TIMES.

*> 32-byte digest d[32], and the 64-byte padded block b[64]
01 DIG-T.
   05 DBYTE       PIC S9(9)  COMP-5 OCCURS 32 TIMES.
01 BLK-T.
   05 BBYTE       PIC S9(9)  COMP-5 OCCURS 64 TIMES.

*> SHA-256 compression working registers
01 REGA              PIC S9(18) COMP-5.
01 REGB              PIC S9(18) COMP-5.
01 REGC              PIC S9(18) COMP-5.
01 REGD              PIC S9(18) COMP-5.
01 REGE              PIC S9(18) COMP-5.
01 REGF              PIC S9(18) COMP-5.
01 REGG              PIC S9(18) COMP-5.
01 REGH              PIC S9(18) COMP-5.
01 WS-S0           PIC S9(18) COMP-5.
01 WS-S1           PIC S9(18) COMP-5.
01 WS-CH           PIC S9(18) COMP-5.
01 WS-MAJ          PIC S9(18) COMP-5.
01 WS-T1           PIC S9(18) COMP-5.
01 WS-T2           PIC S9(18) COMP-5.
01 WS-ACC          PIC S9(18) COMP-5.

*> bit-op subroutine arguments / scratch (linkage-free, in-module)
01 BOPX              PIC S9(18) COMP-5.
01 BOPY              PIC S9(18) COMP-5.
01 BRES            PIC S9(18) COMP-5.
01 BIT-I           PIC S9(9)  COMP-5.
01 BOPX-BIT          PIC S9(18) COMP-5.
01 BOPY-BIT          PIC S9(18) COMP-5.
01 BPOW            PIC S9(18) COMP-5.

*> rotate / shift scratch
01 RT-X            PIC S9(18) COMP-5.
01 RT-N            PIC S9(9)  COMP-5.
01 RT-RES          PIC S9(18) COMP-5.
01 SH-LO           PIC S9(18) COMP-5.
01 SH-HI           PIC S9(18) COMP-5.
01 POW2-N          PIC S9(18) COMP-5.
01 POW2-32MN       PIC S9(18) COMP-5.

*> LCG seed generation
01 LCG-S           PIC S9(18) COMP-5.

*> poly-hash checksum
01 WS-P            PIC S9(18) COMP-5 VALUE 1000000007.
01 WS-HASH         PIC S9(18) COMP-5 VALUE 0.

*> loop counters
01 WS-I            PIC S9(9)  COMP-5.
01 WS-J            PIC S9(9)  COMP-5.
01 WS-ITER         PIC S9(9)  COMP-5.
01 WS-BASE         PIC S9(9)  COMP-5.

*> powers of two table 2^0 .. 2^32 (for shifts/rotates and bit extraction)
01 POW-T.
   05 POW2         PIC S9(18) COMP-5 OCCURS 33 TIMES.

01 ED-CK           PIC -(18)9.
01 ED-N            PIC Z(8)9.

PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF

    PERFORM INIT-CONSTS

    *> LCG seed the 32-byte digest:
    *> s = 42; for i: s = (s*1103515245 + 12345) & 0x7fffffff; d[i] = s % 256
    MOVE 42 TO LCG-S
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 32
       COMPUTE LCG-S = FUNCTION MOD(
            LCG-S * 1103515245 + 12345, 2147483648)
       COMPUTE DBYTE(WS-I) = FUNCTION MOD(LCG-S, 256)
    END-PERFORM

    *> apply SHA-256 to the 32-byte digest N times
    PERFORM VARYING WS-ITER FROM 1 BY 1 UNTIL WS-ITER > WS-N
       PERFORM SHA256-32
    END-PERFORM

    *> checksum: h = 0; for i: h = (h*31 + d[i]) % 1000000007
    MOVE 0 TO WS-HASH
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 32
       COMPUTE WS-HASH = FUNCTION MOD(WS-HASH * 31 + DBYTE(WS-I), WS-P)
    END-PERFORM

    MOVE WS-HASH TO ED-CK
    MOVE WS-N    TO ED-N
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "sha256(" FUNCTION TRIM(ED-N) ")"
    STOP RUN.

*> ---------------------------------------------------------------------------
*> hash the 32-byte digest in place: one padded 64-byte block, msg length 256 bits
SHA256-32.
    *> copy digest into block, then pad
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 32
       MOVE DBYTE(WS-I) TO BBYTE(WS-I)
    END-PERFORM
    MOVE 128 TO BBYTE(33)          *> b[32] = 0x80
    PERFORM VARYING WS-I FROM 34 BY 1 UNTIL WS-I > 64
       MOVE 0 TO BBYTE(WS-I)
    END-PERFORM
    MOVE 1 TO BBYTE(63)            *> b[62] = 1  (length 256 = 0x0100)

    *> h = H0
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 8
       MOVE HH0(WS-I) TO HV(WS-I)
    END-PERFORM

    PERFORM SHA256-BLOCK

    *> store h back into digest big-endian
    PERFORM VARYING WS-I FROM 0 BY 1 UNTIL WS-I > 7
       COMPUTE WS-BASE = WS-I * 4
       MOVE HV(WS-I + 1) TO RT-X
       *> byte 0 (>> 24)
       COMPUTE DBYTE(WS-BASE + 1) =
            FUNCTION MOD(FUNCTION INTEGER(RT-X / POW2(25)), 256)
       COMPUTE DBYTE(WS-BASE + 2) =
            FUNCTION MOD(FUNCTION INTEGER(RT-X / POW2(17)), 256)
       COMPUTE DBYTE(WS-BASE + 3) =
            FUNCTION MOD(FUNCTION INTEGER(RT-X / POW2(9)), 256)
       COMPUTE DBYTE(WS-BASE + 4) = FUNCTION MOD(RT-X, 256)
    END-PERFORM.

*> ---------------------------------------------------------------------------
*> the SHA-256 compression of one 64-byte block in BLK-T into HASH-T
SHA256-BLOCK.
    *> w[0..15] from big-endian bytes
    PERFORM VARYING WS-I FROM 0 BY 1 UNTIL WS-I > 15
       COMPUTE WS-BASE = WS-I * 4
       COMPUTE WW(WS-I + 1) =
            BBYTE(WS-BASE + 1) * POW2(25)
          + BBYTE(WS-BASE + 2) * POW2(17)
          + BBYTE(WS-BASE + 3) * POW2(9)
          + BBYTE(WS-BASE + 4)
    END-PERFORM

    *> w[16..63] = w[i-16] + s0 + w[i-7] + s1  (mod 2^32)
    PERFORM VARYING WS-I FROM 16 BY 1 UNTIL WS-I > 63
       *> s0 = rotr(w[i-15],7) ^ rotr(w[i-15],18) ^ (w[i-15] >> 3)
       MOVE WW(WS-I - 15 + 1) TO RT-X
       MOVE 7 TO RT-N  PERFORM ROTR
       MOVE RT-RES TO BOPX
       MOVE WW(WS-I - 15 + 1) TO RT-X
       MOVE 18 TO RT-N  PERFORM ROTR
       MOVE RT-RES TO BOPY
       PERFORM BIT-XOR
       MOVE BRES TO BOPX
       MOVE WW(WS-I - 15 + 1) TO RT-X
       MOVE 3 TO RT-N  PERFORM SHR
       MOVE RT-RES TO BOPY
       PERFORM BIT-XOR
       MOVE BRES TO WS-S0

       *> s1 = rotr(w[i-2],17) ^ rotr(w[i-2],19) ^ (w[i-2] >> 10)
       MOVE WW(WS-I - 2 + 1) TO RT-X
       MOVE 17 TO RT-N  PERFORM ROTR
       MOVE RT-RES TO BOPX
       MOVE WW(WS-I - 2 + 1) TO RT-X
       MOVE 19 TO RT-N  PERFORM ROTR
       MOVE RT-RES TO BOPY
       PERFORM BIT-XOR
       MOVE BRES TO BOPX
       MOVE WW(WS-I - 2 + 1) TO RT-X
       MOVE 10 TO RT-N  PERFORM SHR
       MOVE RT-RES TO BOPY
       PERFORM BIT-XOR
       MOVE BRES TO WS-S1

       COMPUTE WW(WS-I + 1) = FUNCTION MOD(
            WW(WS-I - 16 + 1) + WS-S0 + WW(WS-I - 7 + 1) + WS-S1,
            WS-MOD32)
    END-PERFORM

    MOVE HV(1) TO REGA
    MOVE HV(2) TO REGB
    MOVE HV(3) TO REGC
    MOVE HV(4) TO REGD
    MOVE HV(5) TO REGE
    MOVE HV(6) TO REGF
    MOVE HV(7) TO REGG
    MOVE HV(8) TO REGH

    PERFORM VARYING WS-I FROM 0 BY 1 UNTIL WS-I > 63
       *> S1 = rotr(e,6) ^ rotr(e,11) ^ rotr(e,25)
       MOVE REGE TO RT-X  MOVE 6 TO RT-N  PERFORM ROTR
       MOVE RT-RES TO BOPX
       MOVE REGE TO RT-X  MOVE 11 TO RT-N  PERFORM ROTR
       MOVE RT-RES TO BOPY
       PERFORM BIT-XOR
       MOVE BRES TO BOPX
       MOVE REGE TO RT-X  MOVE 25 TO RT-N  PERFORM ROTR
       MOVE RT-RES TO BOPY
       PERFORM BIT-XOR
       MOVE BRES TO WS-S1

       *> ch = (e & f) ^ (~e & g)
       MOVE REGE TO BOPX  MOVE REGF TO BOPY  PERFORM BIT-AND
       MOVE BRES TO WS-CH
       MOVE REGE TO RT-X  PERFORM BIT-NOT
       MOVE BRES TO BOPX  MOVE REGG TO BOPY  PERFORM BIT-AND
       MOVE WS-CH TO BOPX  MOVE BRES TO BOPY  PERFORM BIT-XOR
       MOVE BRES TO WS-CH

       *> t1 = h + S1 + ch + K[i] + w[i]   (mod 2^32)
       COMPUTE WS-T1 = FUNCTION MOD(
            REGH + WS-S1 + WS-CH + KK(WS-I + 1) + WW(WS-I + 1), WS-MOD32)

       *> S0 = rotr(a,2) ^ rotr(a,13) ^ rotr(a,22)
       MOVE REGA TO RT-X  MOVE 2 TO RT-N  PERFORM ROTR
       MOVE RT-RES TO BOPX
       MOVE REGA TO RT-X  MOVE 13 TO RT-N  PERFORM ROTR
       MOVE RT-RES TO BOPY
       PERFORM BIT-XOR
       MOVE BRES TO BOPX
       MOVE REGA TO RT-X  MOVE 22 TO RT-N  PERFORM ROTR
       MOVE RT-RES TO BOPY
       PERFORM BIT-XOR
       MOVE BRES TO WS-S0

       *> maj = (a & b) ^ (a & c) ^ (b & c)
       MOVE REGA TO BOPX  MOVE REGB TO BOPY  PERFORM BIT-AND
       MOVE BRES TO WS-MAJ
       MOVE REGA TO BOPX  MOVE REGC TO BOPY  PERFORM BIT-AND
       MOVE WS-MAJ TO BOPX  MOVE BRES TO BOPY  PERFORM BIT-XOR
       MOVE BRES TO WS-MAJ
       MOVE REGB TO BOPX  MOVE REGC TO BOPY  PERFORM BIT-AND
       MOVE WS-MAJ TO BOPX  MOVE BRES TO BOPY  PERFORM BIT-XOR
       MOVE BRES TO WS-MAJ

       *> t2 = S0 + maj  (mod 2^32)
       COMPUTE WS-T2 = FUNCTION MOD(WS-S0 + WS-MAJ, WS-MOD32)

       *> h=g; g=f; f=e; e=d+t1; d=c; c=b; b=a; a=t1+t2
       MOVE REGG TO REGH
       MOVE REGF TO REGG
       MOVE REGE TO REGF
       COMPUTE REGE = FUNCTION MOD(REGD + WS-T1, WS-MOD32)
       MOVE REGC TO REGD
       MOVE REGB TO REGC
       MOVE REGA TO REGB
       COMPUTE REGA = FUNCTION MOD(WS-T1 + WS-T2, WS-MOD32)
    END-PERFORM

    COMPUTE HV(1) = FUNCTION MOD(HV(1) + REGA, WS-MOD32)
    COMPUTE HV(2) = FUNCTION MOD(HV(2) + REGB, WS-MOD32)
    COMPUTE HV(3) = FUNCTION MOD(HV(3) + REGC, WS-MOD32)
    COMPUTE HV(4) = FUNCTION MOD(HV(4) + REGD, WS-MOD32)
    COMPUTE HV(5) = FUNCTION MOD(HV(5) + REGE, WS-MOD32)
    COMPUTE HV(6) = FUNCTION MOD(HV(6) + REGF, WS-MOD32)
    COMPUTE HV(7) = FUNCTION MOD(HV(7) + REGG, WS-MOD32)
    COMPUTE HV(8) = FUNCTION MOD(HV(8) + REGH, WS-MOD32).

*> ---------------------------------------------------------------------------
*> ROTR: RT-RES = rotr32(RT-X, RT-N) = (x >> n) | (x << (32-n)), 32-bit
ROTR.
    MOVE POW2(RT-N + 1)       TO POW2-N
    MOVE POW2(32 - RT-N + 1)  TO POW2-32MN
    *> low part: x >> n
    COMPUTE SH-LO = FUNCTION INTEGER(RT-X / POW2-N)
    *> high part: (x << (32-n)) mod 2^32  ==  (x mod 2^n) * 2^(32-n)
    COMPUTE SH-HI = FUNCTION MOD(RT-X, POW2-N) * POW2-32MN
    *> the two parts occupy disjoint bit ranges, so OR == sum
    COMPUTE RT-RES = SH-LO + SH-HI.

*> SHR: RT-RES = RT-X >> RT-N  (logical right shift, 32-bit value)
SHR.
    MOVE POW2(RT-N + 1) TO POW2-N
    COMPUTE RT-RES = FUNCTION INTEGER(RT-X / POW2-N).

*> ---------------------------------------------------------------------------
*> BIT-XOR: BRES = BOPX xor BOPY   (32-bit, bitwise)
BIT-XOR.
    MOVE 0 TO BRES
    MOVE BOPX TO BOPX-BIT
    MOVE BOPY TO BOPY-BIT
    PERFORM VARYING BIT-I FROM 0 BY 1 UNTIL BIT-I > 31
       IF FUNCTION MOD(BOPX-BIT, 2) NOT = FUNCTION MOD(BOPY-BIT, 2)
          ADD POW2(BIT-I + 1) TO BRES
       END-IF
       COMPUTE BOPX-BIT = FUNCTION INTEGER(BOPX-BIT / 2)
       COMPUTE BOPY-BIT = FUNCTION INTEGER(BOPY-BIT / 2)
    END-PERFORM.

*> BIT-AND: BRES = BOPX and BOPY   (32-bit, bitwise)
BIT-AND.
    MOVE 0 TO BRES
    MOVE BOPX TO BOPX-BIT
    MOVE BOPY TO BOPY-BIT
    PERFORM VARYING BIT-I FROM 0 BY 1 UNTIL BIT-I > 31
       IF FUNCTION MOD(BOPX-BIT, 2) = 1 AND FUNCTION MOD(BOPY-BIT, 2) = 1
          ADD POW2(BIT-I + 1) TO BRES
       END-IF
       COMPUTE BOPX-BIT = FUNCTION INTEGER(BOPX-BIT / 2)
       COMPUTE BOPY-BIT = FUNCTION INTEGER(BOPY-BIT / 2)
    END-PERFORM.

*> BIT-NOT: BRES = (~RT-X) & 0xFFFFFFFF  ==  2^32 - 1 - x
BIT-NOT.
    COMPUTE BRES = 4294967295 - RT-X.

*> ---------------------------------------------------------------------------
INIT-CONSTS.
    *> powers of two 2^0 .. 2^32  -> POW2(1..33)
    MOVE 1 TO POW2(1)
    PERFORM VARYING WS-I FROM 2 BY 1 UNTIL WS-I > 33
       COMPUTE POW2(WS-I) = POW2(WS-I - 1) * 2
    END-PERFORM

    *> H0[8]
    MOVE 1779033703 TO HH0(1)
    MOVE 3144134277 TO HH0(2)
    MOVE 1013904242 TO HH0(3)
    MOVE 2773480762 TO HH0(4)
    MOVE 1359893119 TO HH0(5)
    MOVE 2600822924 TO HH0(6)
    MOVE  528734635 TO HH0(7)
    MOVE 1541459225 TO HH0(8)

    *> K[64]
    MOVE 1116352408 TO KK(1)
    MOVE 1899447441 TO KK(2)
    MOVE 3049323471 TO KK(3)
    MOVE 3921009573 TO KK(4)
    MOVE  961987163 TO KK(5)
    MOVE 1508970993 TO KK(6)
    MOVE 2453635748 TO KK(7)
    MOVE 2870763221 TO KK(8)
    MOVE 3624381080 TO KK(9)
    MOVE  310598401 TO KK(10)
    MOVE  607225278 TO KK(11)
    MOVE 1426881987 TO KK(12)
    MOVE 1925078388 TO KK(13)
    MOVE 2162078206 TO KK(14)
    MOVE 2614888103 TO KK(15)
    MOVE 3248222580 TO KK(16)
    MOVE 3835390401 TO KK(17)
    MOVE 4022224774 TO KK(18)
    MOVE  264347078 TO KK(19)
    MOVE  604807628 TO KK(20)
    MOVE  770255983 TO KK(21)
    MOVE 1249150122 TO KK(22)
    MOVE 1555081692 TO KK(23)
    MOVE 1996064986 TO KK(24)
    MOVE 2554220882 TO KK(25)
    MOVE 2821834349 TO KK(26)
    MOVE 2952996808 TO KK(27)
    MOVE 3210313671 TO KK(28)
    MOVE 3336571891 TO KK(29)
    MOVE 3584528711 TO KK(30)
    MOVE  113926993 TO KK(31)
    MOVE  338241895 TO KK(32)
    MOVE  666307205 TO KK(33)
    MOVE  773529912 TO KK(34)
    MOVE 1294757372 TO KK(35)
    MOVE 1396182291 TO KK(36)
    MOVE 1695183700 TO KK(37)
    MOVE 1986661051 TO KK(38)
    MOVE 2177026350 TO KK(39)
    MOVE 2456956037 TO KK(40)
    MOVE 2730485921 TO KK(41)
    MOVE 2820302411 TO KK(42)
    MOVE 3259730800 TO KK(43)
    MOVE 3345764771 TO KK(44)
    MOVE 3516065817 TO KK(45)
    MOVE 3600352804 TO KK(46)
    MOVE 4094571909 TO KK(47)
    MOVE  275423344 TO KK(48)
    MOVE  430227734 TO KK(49)
    MOVE  506948616 TO KK(50)
    MOVE  659060556 TO KK(51)
    MOVE  883997877 TO KK(52)
    MOVE  958139571 TO KK(53)
    MOVE 1322822218 TO KK(54)
    MOVE 1537002063 TO KK(55)
    MOVE 1747873779 TO KK(56)
    MOVE 1955562222 TO KK(57)
    MOVE 2024104815 TO KK(58)
    MOVE 2227730452 TO KK(59)
    MOVE 2361852424 TO KK(60)
    MOVE 2428436474 TO KK(61)
    MOVE 2756734187 TO KK(62)
    MOVE 3204031479 TO KK(63)
    MOVE 3329325298 TO KK(64).
