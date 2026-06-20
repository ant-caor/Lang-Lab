>>SOURCE FORMAT FREE
*> fannkuch-redux: permutation benchmark, integer-only, no allocation. Faithful port of
*> languages/c/fannkuch.c. Output: line 1 = parity-weighted checksum, line 2 =
*> Pfannkuchen(n) = max flips. Native ELF via cobc -> bit-exact under qemu+insn.
IDENTIFICATION DIVISION.
PROGRAM-ID. fannkuch.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            PIC S9(9)  COMP-5 VALUE 7.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 PERM1-T.
   05 P1           PIC S9(9)  COMP-5 OCCURS 32 TIMES.
01 PERM-T.
   05 PP           PIC S9(9)  COMP-5 OCCURS 32 TIMES.
01 CNT-T.
   05 CC           PIC S9(9)  COMP-5 OCCURS 32 TIMES.
01 WS-MAXFLIPS     PIC S9(9)  COMP-5 VALUE 0.
01 WS-CHECKSUM     PIC S9(18) COMP-5 VALUE 0.
01 WS-R            PIC S9(9)  COMP-5.
01 WS-PERMIDX      PIC S9(18) COMP-5 VALUE 0.
01 WS-FLIPS        PIC S9(9)  COMP-5.
01 WS-K            PIC S9(9)  COMP-5.
01 WS-I            PIC S9(9)  COMP-5.
01 WS-J            PIC S9(9)  COMP-5.
01 WS-T            PIC S9(9)  COMP-5.
01 WS-FIRST        PIC S9(9)  COMP-5.
01 WS-PARITY       PIC S9(9)  COMP-5.
01 WS-DONE         PIC 9              VALUE 0.
01 WS-NEVER        PIC 9              VALUE 0.
01 ED-CK           PIC -(18)9.
01 ED-N            PIC Z(8)9.
01 ED-MF           PIC Z(8)9.
PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF

    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
       COMPUTE P1(WS-I) = WS-I - 1
    END-PERFORM
    MOVE WS-N TO WS-R

    PERFORM UNTIL WS-NEVER = 1
       PERFORM UNTIL WS-R = 1
          MOVE WS-R TO CC(WS-R)
          SUBTRACT 1 FROM WS-R
       END-PERFORM

       PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
          MOVE P1(WS-I) TO PP(WS-I)
       END-PERFORM

       MOVE 0 TO WS-FLIPS
       PERFORM UNTIL PP(1) = 0
          MOVE PP(1) TO WS-K
          MOVE 1 TO WS-I
          COMPUTE WS-J = WS-K + 1
          PERFORM UNTIL WS-I >= WS-J
             MOVE PP(WS-I) TO WS-T
             MOVE PP(WS-J) TO PP(WS-I)
             MOVE WS-T     TO PP(WS-J)
             ADD 1 TO WS-I
             SUBTRACT 1 FROM WS-J
          END-PERFORM
          ADD 1 TO WS-FLIPS
       END-PERFORM

       IF WS-FLIPS > WS-MAXFLIPS
          MOVE WS-FLIPS TO WS-MAXFLIPS
       END-IF
       COMPUTE WS-PARITY = FUNCTION MOD(WS-PERMIDX, 2)
       IF WS-PARITY = 0
          ADD WS-FLIPS TO WS-CHECKSUM
       ELSE
          SUBTRACT WS-FLIPS FROM WS-CHECKSUM
       END-IF

       MOVE 0 TO WS-DONE
       PERFORM UNTIL WS-DONE = 1
          IF WS-R = WS-N
             MOVE WS-CHECKSUM TO ED-CK
             MOVE WS-N        TO ED-N
             MOVE WS-MAXFLIPS TO ED-MF
             DISPLAY FUNCTION TRIM(ED-CK)
             DISPLAY "Pfannkuchen(" FUNCTION TRIM(ED-N) ") = "
                     FUNCTION TRIM(ED-MF)
             STOP RUN
          END-IF
          MOVE P1(1) TO WS-FIRST
          PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-R
             MOVE P1(WS-I + 1) TO P1(WS-I)
          END-PERFORM
          COMPUTE P1(WS-R + 1) = WS-FIRST
          SUBTRACT 1 FROM CC(WS-R + 1)
          IF CC(WS-R + 1) > 0
             MOVE 1 TO WS-DONE
          ELSE
             ADD 1 TO WS-R
          END-IF
       END-PERFORM
       ADD 1 TO WS-PERMIDX
    END-PERFORM
    STOP RUN.
