>>SOURCE FORMAT FREE
*> blur: 2D image-convolution / stencil benchmark. Faithful port of languages/c/blur.c.
*> Generates an N x N grayscale image via a glibc-style LCG, applies a 3x3 Gaussian blur
*> [1,2,1;2,4,2;1,2,1]/16 PASSES=4 times (double-buffered, swap), clamp (edge-replication)
*> borders, integer acc/16 floor division, then poly-hashes the final image. All integer.
*> Two OCCURS flat buffers swapped each pass via a parity flag. Output: line 1 = checksum,
*> line 2 = blur(n). Native ELF via cobc -> bit-exact under qemu+insn.
IDENTIFICATION DIVISION.
PROGRAM-ID. blur.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            PIC S9(9)  COMP-5 VALUE 256.
01 WS-NN          PIC S9(18) COMP-5.
01 WS-ARG         PIC X(16)         VALUE SPACES.
*> two flat double-buffers, 1-indexed; max size 256*256 = 65536
01 BUF-A.
   05 BA          PIC S9(9)  COMP-5 OCCURS 65536 TIMES.
01 BUF-B.
   05 BB          PIC S9(9)  COMP-5 OCCURS 65536 TIMES.
*> kernel weights, 1-indexed (K[(di+1)*3+(dj+1)] -> KW(idx+1))
01 KERN-T.
   05 KW          PIC S9(9)  COMP-5 OCCURS 9 TIMES.
01 WS-S           PIC S9(18) COMP-5 VALUE 42.
01 WS-PROD        PIC S9(18) COMP-5.
01 WS-PASS        PIC S9(9)  COMP-5.
01 WS-I           PIC S9(9)  COMP-5.
01 WS-J           PIC S9(9)  COMP-5.
01 WS-DI          PIC S9(9)  COMP-5.
01 WS-DJ          PIC S9(9)  COMP-5.
01 WS-NI          PIC S9(9)  COMP-5.
01 WS-NJ          PIC S9(9)  COMP-5.
01 WS-ACC         PIC S9(18) COMP-5.
01 WS-KIDX        PIC S9(9)  COMP-5.
01 WS-SIDX        PIC S9(18) COMP-5.
01 WS-DIDX        PIC S9(18) COMP-5.
01 WS-K           PIC S9(18) COMP-5.
01 WS-VAL         PIC S9(9)  COMP-5.
01 WS-H           PIC S9(18) COMP-5 VALUE 0.
01 WS-SRCISA      PIC 9              VALUE 1.
01 WS-PVAL        PIC S9(18) COMP-5.
01 ED-CK          PIC -(18)9.
01 ED-N           PIC Z(8)9.
PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF
    COMPUTE WS-NN = WS-N * WS-N

    *> kernel {1,2,1,2,4,2,1,2,1}
    MOVE 1 TO KW(1)  MOVE 2 TO KW(2)  MOVE 1 TO KW(3)
    MOVE 2 TO KW(4)  MOVE 4 TO KW(5)  MOVE 2 TO KW(6)
    MOVE 1 TO KW(7)  MOVE 2 TO KW(8)  MOVE 1 TO KW(9)

    *> generate source image into BUF-A
    MOVE 42 TO WS-S
    PERFORM VARYING WS-K FROM 1 BY 1 UNTIL WS-K > WS-NN
       COMPUTE WS-S = FUNCTION MOD(WS-S * 1103515245 + 12345, 2147483648)
       MOVE FUNCTION MOD(WS-S, 256) TO BA(WS-K)
    END-PERFORM

    MOVE 1 TO WS-SRCISA
    PERFORM VARYING WS-PASS FROM 0 BY 1 UNTIL WS-PASS >= 4
       PERFORM ONE-PASS
       *> swap: toggle which buffer is the source
       IF WS-SRCISA = 1
          MOVE 0 TO WS-SRCISA
       ELSE
          MOVE 1 TO WS-SRCISA
       END-IF
    END-PERFORM

    *> poly-hash the final image (source buffer after the swaps)
    MOVE 0 TO WS-H
    PERFORM VARYING WS-K FROM 1 BY 1 UNTIL WS-K > WS-NN
       IF WS-SRCISA = 1
          MOVE BA(WS-K) TO WS-PVAL
       ELSE
          MOVE BB(WS-K) TO WS-PVAL
       END-IF
       COMPUTE WS-H = FUNCTION MOD(WS-H * 31 + WS-PVAL, 1000000007)
    END-PERFORM

    MOVE WS-H TO ED-CK
    MOVE WS-N TO ED-N
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "blur(" FUNCTION TRIM(ED-N) ")"
    STOP RUN.

ONE-PASS.
    PERFORM VARYING WS-I FROM 0 BY 1 UNTIL WS-I >= WS-N
       PERFORM VARYING WS-J FROM 0 BY 1 UNTIL WS-J >= WS-N
          MOVE 0 TO WS-ACC
          PERFORM VARYING WS-DI FROM -1 BY 1 UNTIL WS-DI > 1
             COMPUTE WS-NI = WS-I + WS-DI
             IF WS-NI < 0
                MOVE 0 TO WS-NI
             ELSE
                IF WS-NI >= WS-N
                   COMPUTE WS-NI = WS-N - 1
                END-IF
             END-IF
             PERFORM VARYING WS-DJ FROM -1 BY 1 UNTIL WS-DJ > 1
                COMPUTE WS-NJ = WS-J + WS-DJ
                IF WS-NJ < 0
                   MOVE 0 TO WS-NJ
                ELSE
                   IF WS-NJ >= WS-N
                      COMPUTE WS-NJ = WS-N - 1
                   END-IF
                END-IF
                COMPUTE WS-KIDX = (WS-DI + 1) * 3 + (WS-DJ + 1) + 1
                COMPUTE WS-SIDX = WS-NI * WS-N + WS-NJ + 1
                IF WS-SRCISA = 1
                   MOVE BA(WS-SIDX) TO WS-VAL
                ELSE
                   MOVE BB(WS-SIDX) TO WS-VAL
                END-IF
                COMPUTE WS-ACC = WS-ACC + KW(WS-KIDX) * WS-VAL
             END-PERFORM
          END-PERFORM
          COMPUTE WS-DIDX = WS-I * WS-N + WS-J + 1
          COMPUTE WS-PROD = WS-ACC / 16
          IF WS-SRCISA = 1
             MOVE WS-PROD TO BB(WS-DIDX)
          ELSE
             MOVE WS-PROD TO BA(WS-DIDX)
          END-IF
       END-PERFORM
    END-PERFORM.
