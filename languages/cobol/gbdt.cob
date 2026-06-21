>>SOURCE FORMAT FREE
*> gbdt: gradient-boosted decision-tree ensemble inference.
*> Faithful port of languages/c/gbdt.c. B=200 trees of depth D=8 over F=8
*> features. Flat complete binary tree (NODES=511): internal nodes 0..254
*> store (feat,thr); leaves 255..510 store leafval. Children of node k:
*> left=2k+1, right=2k+2. Inference: D=8 compare-and-branch descents per
*> (sample, tree). Checksum: poly-hash of (acc+1) per sample; secondary =
*> sum of acc values mod P. LCG pinned draw order. All integer (COMP-5).
*> Arrays sized for n2=20000:
*>   feat/thr/leafval: B*NODES = 200*511 = 102200 each
*>   sample: N*F = 20000*8 = 160000
IDENTIFICATION DIVISION.
PROGRAM-ID. gbdt.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            PIC S9(9)  COMP-5 VALUE 5000.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 WS-S-LCG        PIC S9(18) COMP-5 VALUE 42.

*> feat[B*NODES]: feature index per internal node, 0..F-1
01 FEAT-T.
   05 FT           PIC S9(9)  COMP-5 OCCURS 102200 TIMES.
*> thr[B*NODES]: threshold per internal node, 0..255
01 THR-T.
   05 TH           PIC S9(9)  COMP-5 OCCURS 102200 TIMES.
*> leafval[B*NODES]: leaf value 0..9
01 LEAF-T.
   05 LV           PIC S9(9)  COMP-5 OCCURS 102200 TIMES.
*> sample[N*F]: feature values 0..255
01 SAMP-T.
   05 SP           PIC S9(9)  COMP-5 OCCURS 160000 TIMES.

*> Loop and work variables
01 WS-B            PIC S9(9)  COMP-5.
01 WS-NODE         PIC S9(9)  COMP-5.
01 WS-I            PIC S9(18) COMP-5.
01 WS-D            PIC S9(9)  COMP-5.
01 WS-BBASE        PIC S9(18) COMP-5.
01 WS-SBASE        PIC S9(18) COMP-5.
01 WS-TBASE        PIC S9(18) COMP-5.
01 WS-IDX          PIC S9(18) COMP-5.
01 WS-FIDX         PIC S9(9)  COMP-5.
01 WS-SVAL         PIC S9(9)  COMP-5.
01 WS-THRVAL       PIC S9(9)  COMP-5.
01 WS-ACC          PIC S9(18) COMP-5.
01 WS-H            PIC S9(18) COMP-5 VALUE 0.
01 WS-TOTAL        PIC S9(18) COMP-5 VALUE 0.

01 ED-CK           PIC -(18)9.
01 ED-N            PIC Z(8)9.
01 ED-SEC          PIC -(18)9.

PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF

    *> --- Build ensemble ---
    *> for b in 0..B-1:
    *>   base = b*NODES
    *>   for node in 0..LEAF_START-1: feat THEN thr
    *>   for node in LEAF_START..NODES-1: leafval
    PERFORM VARYING WS-B FROM 0 BY 1 UNTIL WS-B >= 200
       COMPUTE WS-BBASE = WS-B * 511

       *> internal nodes 0..254: feat then thr
       PERFORM VARYING WS-NODE FROM 0 BY 1 UNTIL WS-NODE >= 255
          PERFORM LCG-STEP
          COMPUTE WS-IDX = WS-BBASE + WS-NODE + 1
          COMPUTE FT(WS-IDX) = FUNCTION MOD(WS-S-LCG, 8)
          PERFORM LCG-STEP
          COMPUTE TH(WS-IDX) = FUNCTION MOD(WS-S-LCG, 256)
       END-PERFORM

       *> leaves 255..510: leafval
       PERFORM VARYING WS-NODE FROM 255 BY 1 UNTIL WS-NODE >= 511
          PERFORM LCG-STEP
          COMPUTE WS-IDX = WS-BBASE + WS-NODE + 1
          COMPUTE LV(WS-IDX) = FUNCTION MOD(WS-S-LCG, 10)
       END-PERFORM
    END-PERFORM

    *> --- Draw samples: N*F draws ---
    COMPUTE WS-I = WS-N * 8
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > WS-I
       PERFORM LCG-STEP
       COMPUTE SP(WS-IDX) = FUNCTION MOD(WS-S-LCG, 256)
    END-PERFORM

    *> --- Inference ---
    MOVE 0 TO WS-H
    MOVE 0 TO WS-TOTAL
    PERFORM VARYING WS-I FROM 0 BY 1 UNTIL WS-I >= WS-N
       COMPUTE WS-SBASE = WS-I * 8
       MOVE 0 TO WS-ACC

       PERFORM VARYING WS-B FROM 0 BY 1 UNTIL WS-B >= 200
          COMPUTE WS-TBASE = WS-B * 511
          MOVE 0 TO WS-NODE

          *> D=8 descents
          PERFORM VARYING WS-D FROM 0 BY 1 UNTIL WS-D >= 8
             COMPUTE WS-IDX = WS-TBASE + WS-NODE + 1
             MOVE FT(WS-IDX) TO WS-FIDX
             COMPUTE WS-IDX = WS-SBASE + WS-FIDX + 1
             MOVE SP(WS-IDX) TO WS-SVAL
             COMPUTE WS-IDX = WS-TBASE + WS-NODE + 1
             MOVE TH(WS-IDX) TO WS-THRVAL
             IF WS-SVAL <= WS-THRVAL
                COMPUTE WS-NODE = 2 * WS-NODE + 1
             ELSE
                COMPUTE WS-NODE = 2 * WS-NODE + 2
             END-IF
          END-PERFORM

          *> accumulate leaf value
          COMPUTE WS-IDX = WS-TBASE + WS-NODE + 1
          COMPUTE WS-ACC = WS-ACC + LV(WS-IDX)
       END-PERFORM

       *> h = (h*31 + acc + 1) % P
       COMPUTE WS-H = FUNCTION MOD(WS-H * 31 + WS-ACC + 1, 1000000007)
       *> total = (total + acc) % P
       COMPUTE WS-TOTAL = FUNCTION MOD(WS-TOTAL + WS-ACC, 1000000007)
    END-PERFORM

    MOVE WS-H     TO ED-CK
    MOVE WS-N     TO ED-N
    MOVE WS-TOTAL TO ED-SEC
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "gbdt(" FUNCTION TRIM(ED-N) ") = "
        FUNCTION TRIM(ED-SEC)
    STOP RUN.

*> s = (s * 1103515245 + 12345) & 0x7fffffff (2147483648 = 2^31)
LCG-STEP.
    COMPUTE WS-S-LCG = WS-S-LCG * 1103515245 + 12345
    COMPUTE WS-S-LCG = FUNCTION MOD(WS-S-LCG, 2147483648)
    .
