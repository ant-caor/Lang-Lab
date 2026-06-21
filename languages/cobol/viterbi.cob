>>SOURCE FORMAT FREE
*> viterbi: integer HMM sequence decoding — the classical max-plus trellis.
*> Faithful port of languages/c/viterbi.c. S=8 states, ALPHA=4 symbols, T=size.
*> LCG (glibc-style, seed=42) draws trans[64], emit[32], obs[T] in that order.
*> Forward trellis: max-plus with STRICT > tie-break (lowest i wins); back-pointer
*> chain stored flat as back[t*8+j]. Backtrace then poly-hash of (path[t]+1).
*> Secondary = vit_prev[bf] mod P. No HMM library; pure integer (COMP-5).
*> Arrays sized for n2=80000: obs 80000, back/path 640000 entries.
IDENTIFICATION DIVISION.
PROGRAM-ID. viterbi.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-T            PIC S9(9)  COMP-5 VALUE 20000.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 WS-S-LCG        PIC S9(18) COMP-5 VALUE 42.

*> trans[64] and emit[32]: scores 1..100, held as S9(18) for the trellis arithmetic
01 TRANS-T.
   05 TR           PIC S9(18) COMP-5 OCCURS 64 TIMES.
01 EMIT-T.
   05 EM           PIC S9(18) COMP-5 OCCURS 32 TIMES.

*> obs[T]: up to 80000; values 0..3 fit in S9(9)
01 OBS-T.
   05 OB           PIC S9(9)  COMP-5 OCCURS 80000 TIMES.

*> Two viterbi column double-buffers (S=8 each)
01 VITA-T.
   05 VA           PIC S9(18) COMP-5 OCCURS 8 TIMES.
01 VITB-T.
   05 VB           PIC S9(18) COMP-5 OCCURS 8 TIMES.

*> back[T*S]: 80000*8 = 640000; values 0..7 fit in S9(9)
01 BACK-T.
   05 BK           PIC S9(9)  COMP-5 OCCURS 640000 TIMES.

*> path[T]: 80000; values 0..7 fit in S9(9)
01 PATH-T.
   05 PT           PIC S9(9)  COMP-5 OCCURS 80000 TIMES.

*> Loop and work variables
01 WS-X            PIC S9(18) COMP-5.
01 WS-I            PIC S9(9)  COMP-5.
01 WS-J            PIC S9(9)  COMP-5.
01 WS-TI           PIC S9(18) COMP-5.
01 WS-BEST         PIC S9(18) COMP-5.
01 WS-BI           PIC S9(9)  COMP-5.
01 WS-SC           PIC S9(18) COMP-5.
01 WS-E-VAL        PIC S9(18) COMP-5.
01 WS-BACK-POS     PIC S9(18) COMP-5.
01 WS-BF           PIC S9(9)  COMP-5.
01 WS-H            PIC S9(18) COMP-5 VALUE 0.
01 WS-SEC          PIC S9(18) COMP-5.
01 WS-PATH-NEXT    PIC S9(9)  COMP-5.

*> Which buffer holds "prev" column: 1=VITA, 2=VITB
01 WS-PREV-BUF     PIC S9(9)  COMP-5 VALUE 1.
01 WS-VIT-VAL      PIC S9(18) COMP-5.
01 WS-VIT-BF       PIC S9(18) COMP-5.

01 ED-CK           PIC -(18)9.
01 ED-N            PIC Z(8)9.
01 ED-SEC          PIC -(18)9.

PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-T = FUNCTION NUMVAL(WS-ARG)
    END-IF

    *> 1. Fill trans[0..63]: rem(state,100)+1
    PERFORM VARYING WS-X FROM 0 BY 1 UNTIL WS-X >= 64
       PERFORM LCG-STEP
       COMPUTE TR(WS-X + 1) = FUNCTION MOD(WS-S-LCG, 100) + 1
    END-PERFORM

    *> 2. Fill emit[0..31]: rem(state,100)+1
    PERFORM VARYING WS-X FROM 0 BY 1 UNTIL WS-X >= 32
       PERFORM LCG-STEP
       COMPUTE EM(WS-X + 1) = FUNCTION MOD(WS-S-LCG, 100) + 1
    END-PERFORM

    *> 3. Fill obs[0..T-1]: rem(state,4)
    PERFORM VARYING WS-X FROM 0 BY 1 UNTIL WS-X >= WS-T
       PERFORM LCG-STEP
       COMPUTE OB(WS-X + 1) = FUNCTION MOD(WS-S-LCG, 4)
    END-PERFORM

    *> 4. Initialise column 0 in VITA: VA(j+1) = EM(j*4 + obs[0] + 1)
    PERFORM VARYING WS-J FROM 0 BY 1 UNTIL WS-J >= 8
       COMPUTE WS-X = WS-J * 4 + OB(1) + 1
       MOVE EM(WS-X) TO VA(WS-J + 1)
    END-PERFORM
    MOVE 1 TO WS-PREV-BUF

    *> 5. Forward trellis ti=1..T-1 with double-buffer swap
    PERFORM VARYING WS-TI FROM 1 BY 1 UNTIL WS-TI >= WS-T
       PERFORM VARYING WS-J FROM 0 BY 1 UNTIL WS-J >= 8
          MOVE -1 TO WS-BEST
          MOVE 0  TO WS-BI
          COMPUTE WS-X = WS-J * 4 + OB(WS-TI + 1) + 1
          MOVE EM(WS-X) TO WS-E-VAL
          PERFORM VARYING WS-I FROM 0 BY 1 UNTIL WS-I >= 8
             COMPUTE WS-X = WS-I * 8 + WS-J + 1
             IF WS-PREV-BUF = 1
                COMPUTE WS-SC = VA(WS-I + 1) + TR(WS-X) + WS-E-VAL
             ELSE
                COMPUTE WS-SC = VB(WS-I + 1) + TR(WS-X) + WS-E-VAL
             END-IF
             IF WS-SC > WS-BEST
                MOVE WS-SC TO WS-BEST
                MOVE WS-I  TO WS-BI
             END-IF
          END-PERFORM
          COMPUTE WS-BACK-POS = WS-TI * 8 + WS-J + 1
          MOVE WS-BI TO BK(WS-BACK-POS)
          IF WS-PREV-BUF = 1
             MOVE WS-BEST TO VB(WS-J + 1)
          ELSE
             MOVE WS-BEST TO VA(WS-J + 1)
          END-IF
       END-PERFORM
       *> swap: flip which buffer is "prev"
       IF WS-PREV-BUF = 1
          MOVE 2 TO WS-PREV-BUF
       ELSE
          MOVE 1 TO WS-PREV-BUF
       END-IF
    END-PERFORM

    *> 6. Find final best state bf (STRICT > -> lowest j wins)
    MOVE 0 TO WS-BF
    PERFORM VARYING WS-J FROM 1 BY 1 UNTIL WS-J >= 8
       IF WS-PREV-BUF = 1
          MOVE VA(WS-J + 1)    TO WS-VIT-VAL
          MOVE VA(WS-BF + 1)   TO WS-VIT-BF
       ELSE
          MOVE VB(WS-J + 1)    TO WS-VIT-VAL
          MOVE VB(WS-BF + 1)   TO WS-VIT-BF
       END-IF
       IF WS-VIT-VAL > WS-VIT-BF
          MOVE WS-J TO WS-BF
       END-IF
    END-PERFORM

    *> path[T-1] = bf  (COBOL 1-based: PT(WS-T))
    MOVE WS-BF TO PT(WS-T)

    *> 7. Backtrace: ti = T-2 downto 0
    *>    path[ti] = back[(ti+1)*8 + path[ti+1]]
    *>    In 1-based COBOL: PT(WS-TI+1) = BK((WS-TI+1)*8 + PT(WS-TI+2) + 1)
    COMPUTE WS-TI = WS-T - 2
    PERFORM UNTIL WS-TI < 0
       MOVE PT(WS-TI + 2) TO WS-PATH-NEXT
       COMPUTE WS-BACK-POS = (WS-TI + 1) * 8 + WS-PATH-NEXT + 1
       MOVE BK(WS-BACK-POS) TO PT(WS-TI + 1)
       SUBTRACT 1 FROM WS-TI
    END-PERFORM

    *> 8. Checksum: h = (h*31 + path[ti] + 1) % P
    MOVE 0 TO WS-H
    PERFORM VARYING WS-TI FROM 0 BY 1 UNTIL WS-TI >= WS-T
       COMPUTE WS-H = FUNCTION MOD(WS-H * 31 + PT(WS-TI + 1) + 1, 1000000007)
    END-PERFORM

    *> 9. Secondary = vit_prev[bf] % P
    IF WS-PREV-BUF = 1
       MOVE VA(WS-BF + 1) TO WS-SEC
    ELSE
       MOVE VB(WS-BF + 1) TO WS-SEC
    END-IF
    COMPUTE WS-SEC = FUNCTION MOD(WS-SEC, 1000000007)

    MOVE WS-H   TO ED-CK
    MOVE WS-T   TO ED-N
    MOVE WS-SEC TO ED-SEC
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "viterbi(" FUNCTION TRIM(ED-N) ") = "
        FUNCTION TRIM(ED-SEC)
    STOP RUN.

*> s = (s * 1103515245 + 12345) & 0x7fffffff (2147483648 = 2^31)
LCG-STEP.
    COMPUTE WS-S-LCG = WS-S-LCG * 1103515245 + 12345
    COMPUTE WS-S-LCG = FUNCTION MOD(WS-S-LCG, 2147483648)
    .
