>>SOURCE FORMAT FREE
*> k-means: integer Lloyd's clustering (K=16, D=4, ITERS=10, RANGE=256).
*> Faithful port of languages/c/k-means.c. Nearest-centroid by integer squared
*> distance, floor-mean centroid update. Pinned: initial centroids = first K
*> points; lowest-index tie-break (strict <); empty cluster keeps its centroid.
*> All integer (COMP-5), so floor-div == truncation (values non-negative).
*> Checksum = poly-hash of final centroids + every assignment (mod 1e9+7).
*> Native ELF via cobc -> bit-exact under qemu+insn.
IDENTIFICATION DIVISION.
PROGRAM-ID. k-means.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            PIC S9(9)  COMP-5 VALUE 8000.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 WS-NTOT        PIC S9(18) COMP-5.
01 WS-S           PIC S9(18) COMP-5 VALUE 42.
*> points: N*D longs (N up to 8000, D=4 => up to 32000)
01 PT-T.
   05 PT          PIC S9(18) COMP-5 OCCURS 32000 TIMES.
*> centroids: K*D = 64 longs
01 CEN-T.
   05 CEN         PIC S9(18) COMP-5 OCCURS 64 TIMES.
*> per-cluster sums: K*D = 64 longs
01 SSUM-T.
   05 SSUM        PIC S9(18) COMP-5 OCCURS 64 TIMES.
*> counts: K longs
01 CNT-T.
   05 CNT         PIC S9(18) COMP-5 OCCURS 16 TIMES.
*> assignments: N ints
01 ASG-T.
   05 ASG         PIC S9(9)  COMP-5 OCCURS 8000 TIMES.
01 WS-I           PIC S9(18) COMP-5.
01 WS-K           PIC S9(9)  COMP-5.
01 WS-D           PIC S9(9)  COMP-5.
01 WS-ITER        PIC S9(9)  COMP-5.
01 WS-BEST        PIC S9(9)  COMP-5.
01 WS-BD          PIC S9(18) COMP-5.
01 WS-DIST        PIC S9(18) COMP-5.
01 WS-DF          PIC S9(18) COMP-5.
01 WS-PBASE       PIC S9(18) COMP-5.
01 WS-CBASE       PIC S9(18) COMP-5.
01 WS-H           PIC S9(18) COMP-5 VALUE 0.
01 ED-CK          PIC -(18)9.
01 ED-N           PIC Z(8)9.
PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF

    *> generate N*D points via LCG: s = (s*1103515245 + 12345) & 0x7fffffff
    COMPUTE WS-NTOT = WS-N * 4
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-NTOT
       COMPUTE WS-S = FUNCTION MOD(
           WS-S * 1103515245 + 12345, 2147483648)
       COMPUTE PT(WS-I) = FUNCTION MOD(WS-S, 256)
    END-PERFORM

    *> initial centroids = first K points (K*D = 64 values)
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 64
       MOVE PT(WS-I) TO CEN(WS-I)
    END-PERFORM

    *> Lloyd iterations
    PERFORM VARYING WS-ITER FROM 0 BY 1 UNTIL WS-ITER >= 10
       *> assignment step
       PERFORM VARYING WS-I FROM 0 BY 1 UNTIL WS-I >= WS-N
          MOVE 0  TO WS-BEST
          MOVE -1 TO WS-BD
          COMPUTE WS-PBASE = WS-I * 4
          PERFORM VARYING WS-K FROM 0 BY 1 UNTIL WS-K >= 16
             MOVE 0 TO WS-DIST
             COMPUTE WS-CBASE = WS-K * 4
             PERFORM VARYING WS-D FROM 0 BY 1 UNTIL WS-D >= 4
                COMPUTE WS-DF =
                    PT(WS-PBASE + WS-D + 1) - CEN(WS-CBASE + WS-D + 1)
                COMPUTE WS-DIST = WS-DIST + WS-DF * WS-DF
             END-PERFORM
             IF WS-BD < 0 OR WS-DIST < WS-BD
                MOVE WS-DIST TO WS-BD
                MOVE WS-K    TO WS-BEST
             END-IF
          END-PERFORM
          MOVE WS-BEST TO ASG(WS-I + 1)
       END-PERFORM

       *> update step: floor-mean, empty cluster unchanged
       PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 64
          MOVE 0 TO SSUM(WS-I)
       END-PERFORM
       PERFORM VARYING WS-K FROM 1 BY 1 UNTIL WS-K > 16
          MOVE 0 TO CNT(WS-K)
       END-PERFORM
       PERFORM VARYING WS-I FROM 0 BY 1 UNTIL WS-I >= WS-N
          MOVE ASG(WS-I + 1) TO WS-K
          ADD 1 TO CNT(WS-K + 1)
          COMPUTE WS-PBASE = WS-I * 4
          COMPUTE WS-CBASE = WS-K * 4
          PERFORM VARYING WS-D FROM 0 BY 1 UNTIL WS-D >= 4
             COMPUTE SSUM(WS-CBASE + WS-D + 1) =
                 SSUM(WS-CBASE + WS-D + 1) + PT(WS-PBASE + WS-D + 1)
          END-PERFORM
       END-PERFORM
       PERFORM VARYING WS-K FROM 0 BY 1 UNTIL WS-K >= 16
          IF CNT(WS-K + 1) > 0
             COMPUTE WS-CBASE = WS-K * 4
             PERFORM VARYING WS-D FROM 0 BY 1 UNTIL WS-D >= 4
                COMPUTE CEN(WS-CBASE + WS-D + 1) =
                    SSUM(WS-CBASE + WS-D + 1) / CNT(WS-K + 1)
             END-PERFORM
          END-IF
       END-PERFORM
    END-PERFORM

    *> final assignment with final centroids
    PERFORM VARYING WS-I FROM 0 BY 1 UNTIL WS-I >= WS-N
       MOVE 0  TO WS-BEST
       MOVE -1 TO WS-BD
       COMPUTE WS-PBASE = WS-I * 4
       PERFORM VARYING WS-K FROM 0 BY 1 UNTIL WS-K >= 16
          MOVE 0 TO WS-DIST
          COMPUTE WS-CBASE = WS-K * 4
          PERFORM VARYING WS-D FROM 0 BY 1 UNTIL WS-D >= 4
             COMPUTE WS-DF =
                 PT(WS-PBASE + WS-D + 1) - CEN(WS-CBASE + WS-D + 1)
             COMPUTE WS-DIST = WS-DIST + WS-DF * WS-DF
          END-PERFORM
          IF WS-BD < 0 OR WS-DIST < WS-BD
             MOVE WS-DIST TO WS-BD
             MOVE WS-K    TO WS-BEST
          END-IF
       END-PERFORM
       MOVE WS-BEST TO ASG(WS-I + 1)
    END-PERFORM

    *> checksum: poly-hash final centroids then all assignments, mod 1e9+7
    MOVE 0 TO WS-H
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 64
       COMPUTE WS-H = FUNCTION MOD(WS-H * 31 + CEN(WS-I), 1000000007)
    END-PERFORM
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
       COMPUTE WS-H = FUNCTION MOD(WS-H * 31 + ASG(WS-I), 1000000007)
    END-PERFORM

    MOVE WS-H TO ED-CK
    MOVE WS-N TO ED-N
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "k-means(" FUNCTION TRIM(ED-N) ")"
    STOP RUN.
