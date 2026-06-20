>>SOURCE FORMAT FREE
*> k-nucleotide: count every length-8 k-mer of an integer-LCG DNA sequence with a
*> hand-rolled open-addressing hash table (FNV-1a + linear probing), then reduce the
*> table to one order-independent checksum. Faithful port of languages/c/k-nucleotide.c
*> (no built-in map -> fair, COBOL is in C's no-builtin-map category). The 64-bit
*> unsigned FNV product (h *= prime mod 2^64) is emulated with two 32-bit limbs since
*> COBOL has no native unsigned overflow. Output: line 1 = checksum, line 2 =
*> k-nucleotide(L). Native ELF via cobc -> bit-exact under qemu+insn.
IDENTIFICATION DIVISION.
PROGRAM-ID. k-nucleotide.
DATA DIVISION.
WORKING-STORAGE SECTION.
*> --- constants matching the C reference ---
01 C-K             PIC S9(9)  COMP-5 VALUE 8.
01 C-P             PIC S9(18) COMP-5 VALUE 1000000007.
01 C-IM            PIC S9(9)  COMP-5 VALUE 139968.
01 C-IA            PIC S9(9)  COMP-5 VALUE 3877.
01 C-IC            PIC S9(9)  COMP-5 VALUE 29573.
01 C-HSIZE         PIC S9(9)  COMP-5 VALUE 262144.
01 C-HMASK         PIC S9(9)  COMP-5 VALUE 262143.
01 C-2P32          PIC S9(18) COMP-5 VALUE 4294967296.
*> FNV-1a basis offset as used by the C reference (the 19-digit literal
*> 1469598103934665603UL, not the standard 20-digit constant), split hi/lo:
*> 1469598103934665603 = 342167472 * 2^32 + 1939669891
01 C-FNV-OFF-HI    PIC S9(18) COMP-5 VALUE 342167472.
01 C-FNV-OFF-LO    PIC S9(18) COMP-5 VALUE 1939669891.
*> FNV prime 1099511628211 = 256 * 2^32 + 435
01 C-FNV-PR-HI     PIC S9(18) COMP-5 VALUE 256.
01 C-FNV-PR-LO     PIC S9(18) COMP-5 VALUE 435.

01 WS-L            PIC S9(9)  COMP-5 VALUE 100000.
01 WS-ARG          PIC X(16)         VALUE SPACES.

*> generated DNA sequence (1-indexed); max length sized generously for n2=200000
01 SEQ-T.
   05 SEQ-B        PIC X OCCURS 200008 TIMES.

*> hash table, parallel arrays, 1-indexed (slot = h+1)
01 HT-KEY-T.
   05 HT-KEY       PIC X(8) OCCURS 262144 TIMES.
01 HT-CNT-T.
   05 HT-CNT       PIC S9(18) COMP-5 OCCURS 262144 TIMES.
01 HT-USED-T.
   05 HT-USED      PIC 9      OCCURS 262144 TIMES.

01 WS-SEED         PIC S9(18) COMP-5.
01 WS-I            PIC S9(9)  COMP-5.
01 WS-J            PIC S9(9)  COMP-5.
01 WS-SLOT         PIC S9(9)  COMP-5.
01 WS-KMER         PIC X(8).
01 WS-BYTE         PIC 9(3)   COMP-5.

*> FNV hash limbs
01 WS-H-HI         PIC S9(18) COMP-5.
01 WS-H-LO         PIC S9(18) COMP-5.
01 WS-T0           PIC S9(18) COMP-5.
01 WS-T1           PIC S9(18) COMP-5.
01 WS-CARRY        PIC S9(18) COMP-5.
01 WS-HASH         PIC S9(18) COMP-5.

*> checksum accumulation
01 WS-ACC          PIC S9(18) COMP-5 VALUE 0.
01 WS-E            PIC S9(18) COMP-5.
01 WS-CODE         PIC S9(9)  COMP-5.
01 WS-CHAR         PIC X.
01 WS-PROD         PIC S9(18) COMP-5.

01 ED-CK           PIC -(18)9.
01 ED-N            PIC Z(8)9.
PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-L = FUNCTION NUMVAL(WS-ARG)
    END-IF

    *> --- gen(L): integer LCG -> DNA bytes ---
    MOVE 42 TO WS-SEED
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-L
       COMPUTE WS-SEED = FUNCTION MOD(WS-SEED * C-IA + C-IC, C-IM)
       EVALUATE TRUE
          WHEN WS-SEED < 42000  MOVE "A" TO SEQ-B(WS-I)
          WHEN WS-SEED < 70000  MOVE "C" TO SEQ-B(WS-I)
          WHEN WS-SEED < 98000  MOVE "G" TO SEQ-B(WS-I)
          WHEN OTHER            MOVE "T" TO SEQ-B(WS-I)
       END-EVALUATE
    END-PERFORM

    *> --- count k-mers: for i = 0 .. L-K, add(s+i) ---
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I + C-K > WS-L + 1
       *> extract the 8-byte k-mer starting at position WS-I
       PERFORM VARYING WS-J FROM 1 BY 1 UNTIL WS-J > C-K
          MOVE SEQ-B(WS-I + WS-J - 1) TO WS-KMER(WS-J:1)
       END-PERFORM
       PERFORM ADD-KMER THRU ADD-KMER-EXIT
    END-PERFORM

    *> --- reduce table to order-independent checksum ---
    MOVE 0 TO WS-ACC
    PERFORM VARYING WS-SLOT FROM 1 BY 1 UNTIL WS-SLOT > C-HSIZE
       IF HT-USED(WS-SLOT) = 1
          MOVE 0 TO WS-E
          PERFORM VARYING WS-J FROM 1 BY 1 UNTIL WS-J > C-K
             MOVE HT-KEY(WS-SLOT)(WS-J:1) TO WS-CHAR
             EVALUATE WS-CHAR
                WHEN "A" MOVE 0 TO WS-CODE
                WHEN "C" MOVE 1 TO WS-CODE
                WHEN "G" MOVE 2 TO WS-CODE
                WHEN OTHER MOVE 3 TO WS-CODE
             END-EVALUATE
             COMPUTE WS-E = WS-E * 4 + WS-CODE
          END-PERFORM
          *> acc = (acc + e * count) mod P  (e < 4^8 = 65536, count < L < 2^21 -> product < 2^37, safe in 64-bit)
          COMPUTE WS-PROD = FUNCTION MOD(WS-E * HT-CNT(WS-SLOT), C-P)
          COMPUTE WS-ACC = FUNCTION MOD(WS-ACC + WS-PROD, C-P)
       END-IF
    END-PERFORM

    MOVE WS-ACC TO ED-CK
    MOVE WS-L   TO ED-N
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "k-nucleotide(" FUNCTION TRIM(ED-N) ")"
    STOP RUN.

*> --- add(kmer): FNV-1a hash + linear probing into the open-addressing table ---
ADD-KMER.
    *> FNV-1a over the 8 bytes, full 64-bit mod 2^64 via two 32-bit limbs
    MOVE C-FNV-OFF-HI TO WS-H-HI
    MOVE C-FNV-OFF-LO TO WS-H-LO
    PERFORM VARYING WS-J FROM 1 BY 1 UNTIL WS-J > C-K
       *> h ^= byte  -> only affects low 8 bits of the low limb
       MOVE WS-KMER(WS-J:1) TO WS-CHAR
       MOVE FUNCTION ORD(WS-CHAR) TO WS-BYTE
       SUBTRACT 1 FROM WS-BYTE
       PERFORM XOR-LOW-BYTE
       *> h *= prime  (mod 2^64), schoolbook: (hi*2^32+lo)*(phi*2^32+plo)
       COMPUTE WS-T0 = WS-H-LO * C-FNV-PR-LO
       COMPUTE WS-CARRY = WS-T0 / C-2P32
       COMPUTE WS-T1 = WS-H-LO * C-FNV-PR-HI
                     + WS-H-HI * C-FNV-PR-LO
                     + WS-CARRY
       COMPUTE WS-H-LO = FUNCTION MOD(WS-T0, C-2P32)
       COMPUTE WS-H-HI = FUNCTION MOD(WS-T1, C-2P32)
    END-PERFORM
    *> h & HMASK: mask is 18 bits, entirely within the low limb
    COMPUTE WS-HASH = FUNCTION MOD(WS-H-LO, C-HSIZE)

    *> linear probe; slot index = hash+1 (1-indexed table)
    COMPUTE WS-SLOT = WS-HASH + 1
    PERFORM UNTIL HT-USED(WS-SLOT) = 0
       IF HT-KEY(WS-SLOT) = WS-KMER
          ADD 1 TO HT-CNT(WS-SLOT)
          GO TO ADD-KMER-EXIT
       END-IF
       *> h = (h+1) & HMASK
       COMPUTE WS-HASH = FUNCTION MOD(WS-HASH + 1, C-HSIZE)
       COMPUTE WS-SLOT = WS-HASH + 1
    END-PERFORM
    MOVE 1 TO HT-USED(WS-SLOT)
    MOVE WS-KMER TO HT-KEY(WS-SLOT)
    MOVE 1 TO HT-CNT(WS-SLOT)
    .
ADD-KMER-EXIT.
    EXIT.

*> XOR the low 8 bits of WS-H-LO with WS-BYTE (0..255), via bit decomposition.
*> Equivalent to: lo = (lo - (lo mod 256)) + ((lo mod 256) XOR byte).
XOR-LOW-BYTE.
    MOVE 0 TO WS-T0
    MOVE 0 TO WS-CARRY
    *> WS-T0 holds the running place value (1,2,4,...,128); WS-CARRY holds result-byte
    COMPUTE WS-T1 = FUNCTION MOD(WS-H-LO, 256)
    *> decompose both bytes bit by bit
    MOVE 1 TO WS-PROD
    PERFORM 8 TIMES
       *> bit of original low byte XOR bit of WS-BYTE
       COMPUTE WS-E = FUNCTION MOD(WS-T1, 2)
       COMPUTE WS-CODE = FUNCTION MOD(WS-BYTE, 2)
       IF WS-E NOT = WS-CODE
          ADD WS-PROD TO WS-CARRY
       END-IF
       COMPUTE WS-T1 = WS-T1 / 2
       COMPUTE WS-BYTE = WS-BYTE / 2
       COMPUTE WS-PROD = WS-PROD * 2
    END-PERFORM
    *> replace low byte of WS-H-LO with the XORed byte
    COMPUTE WS-H-LO = (WS-H-LO - FUNCTION MOD(WS-H-LO, 256)) + WS-CARRY
    .
