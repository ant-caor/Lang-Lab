>>SOURCE FORMAT FREE
*> dijkstra: single-source shortest paths on a deterministically generated weighted
*> digraph, using a HAND-WRITTEN binary min-heap (no stdlib priority queue). Faithful
*> port of languages/c/dijkstra.c. Heap stores PACKED keys key = dist*2^21 + node in
*> a signed 64-bit int (S9(18) COMP-5); a single-int compare is exactly the (dist,node)
*> lexicographic order, and all keys are distinct -> identical heap ops in every lang.
*> Checksum (line 1) = poly-hash of the final dist[] array. Line 2 = dijkstra(n).
*> Native ELF via cobc -> bit-exact under qemu+insn.
IDENTIFICATION DIVISION.
PROGRAM-ID. dijkstra.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            PIC S9(9)  COMP-5 VALUE 10000.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 WS-M            PIC S9(18) COMP-5.
01 WS-S            PIC S9(18) COMP-5.
01 WS-E            PIC S9(18) COMP-5.
01 WS-I            PIC S9(18) COMP-5.
01 WS-POS          PIC S9(18) COMP-5.
01 WS-U            PIC S9(18) COMP-5.
01 WS-V            PIC S9(18) COMP-5.
01 WS-D            PIC S9(18) COMP-5.
01 WS-ND           PIC S9(18) COMP-5.
01 WS-KEY          PIC S9(18) COMP-5.
01 WS-DI           PIC S9(18) COMP-5.
01 WS-H            PIC S9(18) COMP-5 VALUE 0.

*> constants
01 K-P             PIC S9(18) COMP-5 VALUE 1000000007.
01 K-INF           PIC S9(18) COMP-5 VALUE 4611686018427387904.
01 K-BASE          PIC S9(18) COMP-5 VALUE 2097152.
01 K-MAXW          PIC S9(18) COMP-5 VALUE 100.
01 K-MASK          PIC S9(18) COMP-5 VALUE 2147483647.

*> edge arrays (M = 8N; size for n2=20000 -> 160000)
01 EDGE-T.
   05 E-U          PIC S9(9)  COMP-5 OCCURS 160000 TIMES.
   05 E-V          PIC S9(9)  COMP-5 OCCURS 160000 TIMES.
   05 E-W          PIC S9(9)  COMP-5 OCCURS 160000 TIMES.

*> CSR adjacency
01 START-T.
   05 ST           PIC S9(18) COMP-5 OCCURS 20001 TIMES.
01 CNT-T.
   05 CN           PIC S9(18) COMP-5 OCCURS 20000 TIMES.
01 ADJ-T.
   05 ADJV         PIC S9(9)  COMP-5 OCCURS 160000 TIMES.
   05 ADJW         PIC S9(9)  COMP-5 OCCURS 160000 TIMES.

*> dist[]
01 DIST-T.
   05 DST          PIC S9(18) COMP-5 OCCURS 20000 TIMES.

*> binary min-heap of packed keys (size M+1)
01 HEAP-T.
   05 HP           PIC S9(18) COMP-5 OCCURS 160001 TIMES.
01 WS-HSIZE        PIC S9(18) COMP-5 VALUE 0.

*> heap helpers (1-indexed; C index i -> COBOL i+1)
01 HI              PIC S9(18) COMP-5.
01 HP-PAR          PIC S9(18) COMP-5.
01 HL              PIC S9(18) COMP-5.
01 HR              PIC S9(18) COMP-5.
01 HM              PIC S9(18) COMP-5.
01 HT              PIC S9(18) COMP-5.
01 PUSH-K          PIC S9(18) COMP-5.
01 POP-TOP         PIC S9(18) COMP-5.
01 BREAK-FLAG      PIC 9.

01 ED-CK           PIC -(18)9.
01 ED-N            PIC Z(8)9.
PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF
    COMPUTE WS-M = 8 * WS-N

    *> generate edges (e = 0..M-1 -> EDGE arrays 1-indexed at e+1)
    MOVE 42 TO WS-S
    PERFORM VARYING WS-E FROM 0 BY 1 UNTIL WS-E >= WS-M
       PERFORM LCG-STEP
       COMPUTE E-U(WS-E + 1) = FUNCTION MOD(WS-S, WS-N)
       PERFORM LCG-STEP
       COMPUTE E-V(WS-E + 1) = FUNCTION MOD(WS-S, WS-N)
       PERFORM LCG-STEP
       COMPUTE E-W(WS-E + 1) = FUNCTION MOD(WS-S, K-MAXW) + 1
    END-PERFORM

    *> CSR adjacency in forward (edge-generation) order
    *> start[] has indices 0..N (COBOL 1..N+1); init to 0
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N + 1
       MOVE 0 TO ST(WS-I)
    END-PERFORM
    *> start[eu[e]+1]++  -> C index (eu+1), COBOL (eu+2)
    PERFORM VARYING WS-E FROM 0 BY 1 UNTIL WS-E >= WS-M
       COMPUTE WS-U = E-U(WS-E + 1)
       ADD 1 TO ST(WS-U + 2)
    END-PERFORM
    *> prefix sums: start[i+1] += start[i], i = 0..N-1
    PERFORM VARYING WS-I FROM 0 BY 1 UNTIL WS-I >= WS-N
       ADD ST(WS-I + 1) TO ST(WS-I + 2)
    END-PERFORM
    *> cnt[] = 0
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
       MOVE 0 TO CN(WS-I)
    END-PERFORM
    *> scatter into adjV/adjW
    PERFORM VARYING WS-E FROM 0 BY 1 UNTIL WS-E >= WS-M
       COMPUTE WS-U = E-U(WS-E + 1)
       *> pos = start[u] + cnt[u]++  (C 0-based pos)
       COMPUTE WS-POS = ST(WS-U + 1) + CN(WS-U + 1)
       ADD 1 TO CN(WS-U + 1)
       MOVE E-V(WS-E + 1) TO ADJV(WS-POS + 1)
       MOVE E-W(WS-E + 1) TO ADJW(WS-POS + 1)
    END-PERFORM

    *> dist[] = INF, dist[0] = 0
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
       MOVE K-INF TO DST(WS-I)
    END-PERFORM
    MOVE 0 TO DST(1)

    *> heap: push key 0 (dist 0, node 0)
    MOVE 0 TO WS-HSIZE
    MOVE 0 TO PUSH-K
    PERFORM HPUSH

    PERFORM UNTIL WS-HSIZE <= 0
       PERFORM HPOP
       MOVE POP-TOP TO WS-KEY
       COMPUTE WS-D = WS-KEY / K-BASE
       COMPUTE WS-U = FUNCTION MOD(WS-KEY, K-BASE)
       *> stale heap entry?  (C: u is 0-based node)
       IF WS-D > DST(WS-U + 1)
          CONTINUE
       ELSE
          *> relax edges start[u] .. start[u+1]-1  (C 0-based e)
          PERFORM VARYING WS-E FROM ST(WS-U + 1) BY 1
                  UNTIL WS-E >= ST(WS-U + 2)
             COMPUTE WS-V  = ADJV(WS-E + 1)
             COMPUTE WS-ND = WS-D + ADJW(WS-E + 1)
             IF WS-ND < DST(WS-V + 1)
                MOVE WS-ND TO DST(WS-V + 1)
                COMPUTE PUSH-K = WS-ND * K-BASE + WS-V
                PERFORM HPUSH
             END-IF
          END-PERFORM
       END-IF
    END-PERFORM

    *> checksum: poly-hash of dist[] (unreachable -> 0)
    MOVE 0 TO WS-H
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
       IF DST(WS-I) < K-INF
          MOVE DST(WS-I) TO WS-DI
       ELSE
          MOVE 0 TO WS-DI
       END-IF
       COMPUTE WS-H = FUNCTION MOD(WS-H * 31 + FUNCTION MOD(WS-DI, K-P), K-P)
    END-PERFORM

    MOVE WS-H TO ED-CK
    MOVE WS-N TO ED-N
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "dijkstra(" FUNCTION TRIM(ED-N) ")"
    STOP RUN.

*> s = (s * 1103515245 + 12345) & 0x7fffffff
LCG-STEP.
    COMPUTE WS-S = (WS-S * 1103515245 + 12345)
    COMPUTE WS-S = FUNCTION MOD(WS-S, 2147483648)
    .

*> hpush(PUSH-K): append at hsize, sift up
HPUSH.
    *> C: i = hsize++; heap[i] = k;  (COBOL 1-based: index hsize+1)
    MOVE WS-HSIZE TO HI
    ADD 1 TO WS-HSIZE
    MOVE PUSH-K TO HP(HI + 1)
    MOVE 0 TO BREAK-FLAG
    PERFORM UNTIL HI <= 0 OR BREAK-FLAG = 1
       COMPUTE HP-PAR = (HI - 1) / 2
       IF HP(HP-PAR + 1) <= HP(HI + 1)
          MOVE 1 TO BREAK-FLAG
       ELSE
          MOVE HP(HP-PAR + 1) TO HT
          MOVE HP(HI + 1)     TO HP(HP-PAR + 1)
          MOVE HT             TO HP(HI + 1)
          MOVE HP-PAR TO HI
       END-IF
    END-PERFORM
    .

*> hpop -> POP-TOP: take heap[0], move last to root, sift down
HPOP.
    MOVE HP(1) TO POP-TOP
    SUBTRACT 1 FROM WS-HSIZE
    *> heap[0] = heap[--hsize]  (C index hsize after decrement -> COBOL hsize+1)
    MOVE HP(WS-HSIZE + 1) TO HP(1)
    MOVE 0 TO HI
    MOVE 0 TO BREAK-FLAG
    PERFORM UNTIL BREAK-FLAG = 1
       COMPUTE HL = 2 * HI + 1
       COMPUTE HR = 2 * HI + 2
       MOVE HI TO HM
       IF HL < WS-HSIZE AND HP(HL + 1) < HP(HM + 1)
          MOVE HL TO HM
       END-IF
       IF HR < WS-HSIZE AND HP(HR + 1) < HP(HM + 1)
          MOVE HR TO HM
       END-IF
       IF HM = HI
          MOVE 1 TO BREAK-FLAG
       ELSE
          MOVE HP(HM + 1) TO HT
          MOVE HP(HI + 1) TO HP(HM + 1)
          MOVE HT         TO HP(HI + 1)
          MOVE HM TO HI
       END-IF
    END-PERFORM
    .
