>>SOURCE FORMAT FREE
*> sort-search: generate N ints via a glibc-style LCG, sort in place with a
*> hand-written median-of-three Hoare quicksort, then run N binary searches and
*> fold the found indices into a poly-hash checksum. Faithful port of
*> languages/c/sort-search.c. NO library sort/bsearch. All integer, 64-bit;
*> integer (floor) division everywhere. Quicksort recursion is expressed with an
*> explicit manual stack (OCCURS) since Hoare depth stays ~log N. Output: line 1 =
*> checksum, line 2 = sort-search(n). Native ELF via cobc -> bit-exact under qemu+insn.
IDENTIFICATION DIVISION.
PROGRAM-ID. sort-search.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            PIC S9(18) COMP-5 VALUE 100000.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 ARR-T.
   05 A           PIC S9(18) COMP-5 OCCURS 200001 TIMES.
*> Explicit quicksort stack: depth bounded ~2*log2(N); 128 entries is ample.
01 STK-LO-T.
   05 STK-LO      PIC S9(18) COMP-5 OCCURS 128 TIMES.
01 STK-HI-T.
   05 STK-HI      PIC S9(18) COMP-5 OCCURS 128 TIMES.
01 WS-SP          PIC S9(9)  COMP-5 VALUE 0.
01 WS-STATE       PIC S9(18) COMP-5 VALUE 42.
01 WS-CHECKSUM    PIC S9(18) COMP-5 VALUE 0.
01 WS-P           PIC S9(18) COMP-5 VALUE 1000000007.
01 WS-I           PIC S9(18) COMP-5.
01 WS-Q           PIC S9(18) COMP-5.
01 WS-IDX         PIC S9(18) COMP-5.
01 WS-KEY         PIC S9(18) COMP-5.
*> qsort locals
01 QS-LO          PIC S9(18) COMP-5.
01 QS-HI          PIC S9(18) COMP-5.
01 QS-MID         PIC S9(18) COMP-5.
01 QS-PIVOT       PIC S9(18) COMP-5.
01 QS-I           PIC S9(18) COMP-5.
01 QS-J           PIC S9(18) COMP-5.
01 QS-T           PIC S9(18) COMP-5.
*> binary-search locals
01 BS-LO          PIC S9(18) COMP-5.
01 BS-HI          PIC S9(18) COMP-5.
01 BS-MID         PIC S9(18) COMP-5.
01 BS-FOUND       PIC 9              VALUE 0.
01 ED-CK          PIC -(18)9.
01 ED-N           PIC Z(17)9.
PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF

    *> generate N ints (1-indexed table; C a[0..N-1] -> A(1..N))
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
       PERFORM LCG-NEXT
       MOVE WS-STATE TO A(WS-I)
    END-PERFORM

    *> hand-written median-of-three Hoare quicksort over A(1..N)
    MOVE 1    TO QS-LO
    MOVE WS-N TO QS-HI
    PERFORM QSORT-H

    *> N binary searches, fold idx+1 into the checksum
    MOVE 0 TO WS-CHECKSUM
    PERFORM VARYING WS-Q FROM 1 BY 1 UNTIL WS-Q > WS-N
       PERFORM LCG-NEXT
       *> key = a[state % N]  (state >= 0, N > 0 -> plain modulo)
       COMPUTE WS-IDX = FUNCTION MOD(WS-STATE, WS-N)
       MOVE A(WS-IDX + 1) TO WS-KEY
       PERFORM BSEARCH-I
       *> h = (h * 31 + (idx + 1)) % P ; idx is 0-based C index (-1 if miss)
       COMPUTE WS-CHECKSUM =
          FUNCTION MOD(WS-CHECKSUM * 31 + (WS-IDX + 1), WS-P)
    END-PERFORM

    MOVE WS-CHECKSUM TO ED-CK
    MOVE WS-N        TO ED-N
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "sort-search(" FUNCTION TRIM(ED-N) ")"
    STOP RUN.

*> state = (state * 1103515245 + 12345) & 0x7fffffff
*> product fits signed 64-bit (max ~2.4e18 < 9.2e18); mask = MOD by 2^31.
LCG-NEXT.
    COMPUTE WS-STATE =
       FUNCTION MOD(WS-STATE * 1103515245 + 12345, 2147483648).

*> median-of-three + Hoare partition, both sides; explicit stack replaces recursion.
*> Indices here are C-style 0-based (lo,hi); array access uses A(index+1).
QSORT-H.
    *> push initial range; QS-LO/QS-HI hold C-style 0-based bounds
    COMPUTE QS-LO = QS-LO - 1
    COMPUTE QS-HI = QS-HI - 1
    MOVE 1 TO WS-SP
    MOVE QS-LO TO STK-LO(1)
    MOVE QS-HI TO STK-HI(1)
    PERFORM UNTIL WS-SP = 0
       MOVE STK-LO(WS-SP) TO QS-LO
       MOVE STK-HI(WS-SP) TO QS-HI
       SUBTRACT 1 FROM WS-SP
       IF QS-LO < QS-HI
          *> mid = lo + (hi - lo) / 2  (floor division)
          COMPUTE QS-MID = QS-LO + (QS-HI - QS-LO) / 2
          *> median-of-three on a[lo], a[mid], a[hi]
          IF A(QS-MID + 1) < A(QS-LO + 1)
             MOVE A(QS-LO + 1)  TO QS-T
             MOVE A(QS-MID + 1) TO A(QS-LO + 1)
             MOVE QS-T          TO A(QS-MID + 1)
          END-IF
          IF A(QS-HI + 1) < A(QS-LO + 1)
             MOVE A(QS-LO + 1) TO QS-T
             MOVE A(QS-HI + 1) TO A(QS-LO + 1)
             MOVE QS-T         TO A(QS-HI + 1)
          END-IF
          IF A(QS-HI + 1) < A(QS-MID + 1)
             MOVE A(QS-MID + 1) TO QS-T
             MOVE A(QS-HI + 1)  TO A(QS-MID + 1)
             MOVE QS-T          TO A(QS-HI + 1)
          END-IF
          MOVE A(QS-MID + 1) TO QS-PIVOT
          COMPUTE QS-I = QS-LO - 1
          COMPUTE QS-J = QS-HI + 1
          PERFORM UNTIL QS-I >= QS-J
             ADD 1 TO QS-I
             PERFORM UNTIL A(QS-I + 1) >= QS-PIVOT
                ADD 1 TO QS-I
             END-PERFORM
             SUBTRACT 1 FROM QS-J
             PERFORM UNTIL A(QS-J + 1) <= QS-PIVOT
                SUBTRACT 1 FROM QS-J
             END-PERFORM
             IF QS-I < QS-J
                MOVE A(QS-I + 1) TO QS-T
                MOVE A(QS-J + 1) TO A(QS-I + 1)
                MOVE QS-T        TO A(QS-J + 1)
             END-IF
          END-PERFORM
          *> recurse(lo, j) and recurse(j+1, hi) -> push both ranges
          ADD 1 TO WS-SP
          MOVE QS-LO TO STK-LO(WS-SP)
          MOVE QS-J  TO STK-HI(WS-SP)
          ADD 1 TO WS-SP
          COMPUTE STK-LO(WS-SP) = QS-J + 1
          MOVE QS-HI TO STK-HI(WS-SP)
       END-IF
    END-PERFORM.

*> iterative binary search over A(1..N); BS bounds are C-style 0-based.
*> sets WS-IDX to 0-based hit index, or -1 on miss.
BSEARCH-I.
    MOVE 0 TO BS-LO
    COMPUTE BS-HI = WS-N - 1
    MOVE 0 TO BS-FOUND
    MOVE -1 TO WS-IDX
    PERFORM UNTIL BS-LO > BS-HI OR BS-FOUND = 1
       COMPUTE BS-MID = BS-LO + (BS-HI - BS-LO) / 2
       IF A(BS-MID + 1) < WS-KEY
          COMPUTE BS-LO = BS-MID + 1
       ELSE
          IF A(BS-MID + 1) > WS-KEY
             COMPUTE BS-HI = BS-MID - 1
          ELSE
             MOVE BS-MID TO WS-IDX
             MOVE 1 TO BS-FOUND
          END-IF
       END-IF
    END-PERFORM.
