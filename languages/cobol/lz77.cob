>>SOURCE FORMAT FREE
*> lz77: hand-written LZ77 sliding-window compressor over an LCG-generated
*> 6-symbol byte stream. Faithful port of languages/c/lz77.c. WINDOW=512,
*> MIN_MATCH=3, MAX_MATCH=255; brute-force longest match (closest distance
*> wins ties via strict >), greedy parse, poly-hash the token stream
*> (h=h*31+x mod 1e9+7). All integer (S9(18) COMP-5). Native ELF via cobc
*> -> bit-exact under qemu+insn. Output: line 1 = hash, line 2 = lz77(n).
IDENTIFICATION DIVISION.
PROGRAM-ID. lz77.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            PIC S9(9)  COMP-5 VALUE 24000.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 IN-T.
   05 IN-B         PIC S9(9)  COMP-5 OCCURS 24001 TIMES.
01 WS-S            PIC S9(18) COMP-5 VALUE 42.
01 WS-H            PIC S9(18) COMP-5 VALUE 0.
01 WS-POS          PIC S9(9)  COMP-5.
01 WS-BEST-LEN     PIC S9(9)  COMP-5.
01 WS-BEST-DIST    PIC S9(9)  COMP-5.
01 WS-START        PIC S9(9)  COMP-5.
01 WS-CAND         PIC S9(9)  COMP-5.
01 WS-L            PIC S9(9)  COMP-5.
01 WS-I            PIC S9(9)  COMP-5.
01 WS-MATCH        PIC 9              VALUE 0.
01 P-MOD           PIC S9(18) COMP-5 VALUE 1000000007.
01 ED-H            PIC -(18)9.
01 ED-N            PIC Z(8)9.
PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF

    *> generate input: s = lcg(s); in[i] = s % 6
    MOVE 42 TO WS-S
    PERFORM VARYING WS-I FROM 0 BY 1 UNTIL WS-I >= WS-N
       COMPUTE WS-S =
          FUNCTION MOD(WS-S * 1103515245 + 12345, 2147483648)
       COMPUTE IN-B(WS-I + 1) = FUNCTION MOD(WS-S, 6)
    END-PERFORM

    MOVE 0 TO WS-POS
    PERFORM UNTIL WS-POS >= WS-N
       MOVE 0 TO WS-BEST-LEN
       MOVE 0 TO WS-BEST-DIST
       COMPUTE WS-START = WS-POS - 512
       IF WS-START < 0
          MOVE 0 TO WS-START
       END-IF
       *> closest distance first: cand from pos-1 down to start
       COMPUTE WS-CAND = WS-POS - 1
       PERFORM UNTIL WS-CAND < WS-START
          MOVE 0 TO WS-L
          MOVE 0 TO WS-MATCH
          PERFORM UNTIL WS-MATCH = 1
             IF WS-POS + WS-L >= WS-N OR WS-L >= 255
                MOVE 1 TO WS-MATCH
             ELSE
                IF IN-B(WS-CAND + WS-L + 1) = IN-B(WS-POS + WS-L + 1)
                   ADD 1 TO WS-L
                ELSE
                   MOVE 1 TO WS-MATCH
                END-IF
             END-IF
          END-PERFORM
          IF WS-L > WS-BEST-LEN
             MOVE WS-L TO WS-BEST-LEN
             COMPUTE WS-BEST-DIST = WS-POS - WS-CAND
          END-IF
          SUBTRACT 1 FROM WS-CAND
       END-PERFORM

       IF WS-BEST-LEN >= 3
          COMPUTE WS-H = FUNCTION MOD(WS-H * 31 + 1, P-MOD)
          COMPUTE WS-H = FUNCTION MOD(WS-H * 31 + WS-BEST-DIST, P-MOD)
          COMPUTE WS-H = FUNCTION MOD(WS-H * 31 + WS-BEST-LEN, P-MOD)
          ADD WS-BEST-LEN TO WS-POS
       ELSE
          COMPUTE WS-H = FUNCTION MOD(WS-H * 31 + 0, P-MOD)
          COMPUTE WS-H = FUNCTION MOD(WS-H * 31 + IN-B(WS-POS + 1), P-MOD)
          ADD 1 TO WS-POS
       END-IF
    END-PERFORM

    MOVE WS-H TO ED-H
    MOVE WS-N TO ED-N
    DISPLAY FUNCTION TRIM(ED-H)
    DISPLAY "lz77(" FUNCTION TRIM(ED-N) ")"
    STOP RUN.
