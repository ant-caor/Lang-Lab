>>SOURCE FORMAT FREE
*> tak: the Takeuchi function - the function-call / recursion-overhead axis. Faithful port of
*> languages/c/tak.c. Naive triple recursion tak(x,y,z) = y<x ? tak(tak(x-1,y,z),tak(y-1,z,x),
*> tak(z-1,x,y)) : z, size n -> tak(3n,2n,n). NO memoization, NO iterative/tail rewrite. Every
*> entry to tak is counted (incremented before the base test). TAK-FN is a RECURSIVE program;
*> its arguments and the three temporaries live in LOCAL-STORAGE so each recursive instance keeps
*> its own frame, while the shared call counter is passed by reference (LK-CALLS) and accumulates
*> across every instance. Output: line 1 = total call count, line 2 = tak(n) = <result>. Native
*> ELF via cobc.
IDENTIFICATION DIVISION.
PROGRAM-ID. tak.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            PIC S9(9)  COMP-5 VALUE 6.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 WS-X            PIC S9(9)  COMP-5.
01 WS-Y            PIC S9(9)  COMP-5.
01 WS-Z            PIC S9(9)  COMP-5.
01 WS-RESULT       PIC S9(9)  COMP-5.
01 WS-CALLS        PIC S9(18) COMP-5 VALUE 0.
01 ED-CALLS        PIC -(18)9.
01 ED-N            PIC -(9)9.
01 ED-R            PIC -(9)9.
PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF

    COMPUTE WS-X = 3 * WS-N
    COMPUTE WS-Y = 2 * WS-N
    MOVE WS-N TO WS-Z
    CALL "TAK-FN" USING WS-X WS-Y WS-Z WS-RESULT WS-CALLS

    MOVE WS-CALLS  TO ED-CALLS
    MOVE WS-N      TO ED-N
    MOVE WS-RESULT TO ED-R
    DISPLAY FUNCTION TRIM(ED-CALLS)
    DISPLAY "tak(" FUNCTION TRIM(ED-N) ") = " FUNCTION TRIM(ED-R)
    STOP RUN.
END PROGRAM tak.

*> ---------------------------------------------------------------------------
*> RECURSIVE standalone program. Arguments + temporaries are in LOCAL-STORAGE so
*> every recursive instance has its own frame; the call counter (LK-CALLS) is the
*> caller's single cell, passed BY REFERENCE down the whole tree, so it accumulates
*> every entry to tak across all instances.
IDENTIFICATION DIVISION.
PROGRAM-ID. TAK-FN IS RECURSIVE.
DATA DIVISION.
LOCAL-STORAGE SECTION.
01 LS-T1           PIC S9(9)  COMP-5.
01 LS-T2           PIC S9(9)  COMP-5.
01 LS-T3           PIC S9(9)  COMP-5.
01 LS-A1           PIC S9(9)  COMP-5.
01 LS-A2           PIC S9(9)  COMP-5.
01 LS-A3           PIC S9(9)  COMP-5.
LINKAGE SECTION.
01 LK-X            PIC S9(9)  COMP-5.
01 LK-Y            PIC S9(9)  COMP-5.
01 LK-Z            PIC S9(9)  COMP-5.
01 LK-R            PIC S9(9)  COMP-5.
01 LK-CALLS        PIC S9(18) COMP-5.
PROCEDURE DIVISION USING LK-X LK-Y LK-Z LK-R LK-CALLS.
TAK-PARA.
    ADD 1 TO LK-CALLS
    IF LK-Y < LK-X
       COMPUTE LS-A1 = LK-X - 1
       CALL "TAK-FN" USING LS-A1 LK-Y LK-Z LS-T1 LK-CALLS
       COMPUTE LS-A2 = LK-Y - 1
       CALL "TAK-FN" USING LS-A2 LK-Z LK-X LS-T2 LK-CALLS
       COMPUTE LS-A3 = LK-Z - 1
       CALL "TAK-FN" USING LS-A3 LK-X LK-Y LS-T3 LK-CALLS
       CALL "TAK-FN" USING LS-T1 LS-T2 LS-T3 LK-R LK-CALLS
    ELSE
       MOVE LK-Z TO LK-R
    END-IF
    EXIT PROGRAM.
END PROGRAM TAK-FN.
