>>SOURCE FORMAT FREE
*> reverse-complement: generate a DNA sequence via an integer LCG, reverse it in
*> place while complementing each base (A<->T, C<->G) with a hand-written two-pointer
*> loop, then reduce it to a hand polynomial hash h=h*31+ascii mod 1e9+7 over a
*> per-character loop. NO stdlib reverse/translate/builtin-hash. Faithful port of
*> languages/c/reverse-complement.c. The sequence is a byte table (PIC X OCCURS),
*> bases held as their ASCII codes via a binary PIC; 64-bit hash via S9(18) COMP-5.
*> Output: line 1 = checksum, line 2 = reverse-complement(L). Native ELF via cobc.
IDENTIFICATION DIVISION.
PROGRAM-ID. reverse-complement.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-L            PIC S9(9)  COMP-5 VALUE 100000.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 SEQ-T.
   05 SQ           PIC X OCCURS 400000 TIMES.
01 WS-SEED         PIC S9(18) COMP-5 VALUE 42.
01 WS-I            PIC S9(9)  COMP-5.
01 WS-J            PIC S9(9)  COMP-5.
01 WS-K            PIC S9(9)  COMP-5.
01 WS-H            PIC S9(18) COMP-5 VALUE 0.
01 WS-A            PIC X.
01 WS-BYTE         PIC X.
01 WS-CODE         PIC 9(4)   COMP-5.
01 ED-CK           PIC -(18)9.
01 ED-N            PIC Z(8)9.
PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-L = FUNCTION NUMVAL(WS-ARG)
    END-IF

    *> Generate the sequence with the integer LCG (seed starts at 42).
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-L
       COMPUTE WS-SEED = FUNCTION MOD(WS-SEED * 3877 + 29573, 139968)
       EVALUATE TRUE
          WHEN WS-SEED < 42000
             MOVE "A" TO SQ(WS-I)
          WHEN WS-SEED < 70000
             MOVE "C" TO SQ(WS-I)
          WHEN WS-SEED < 98000
             MOVE "G" TO SQ(WS-I)
          WHEN OTHER
             MOVE "T" TO SQ(WS-I)
       END-EVALUATE
    END-PERFORM

    *> Two-pointer reverse-and-complement, in place (1-indexed).
    MOVE 1    TO WS-I
    MOVE WS-L TO WS-J
    PERFORM UNTIL WS-I >= WS-J
       MOVE SQ(WS-I) TO WS-BYTE
       PERFORM COMPLEMENT
       MOVE WS-BYTE TO WS-A
       MOVE SQ(WS-J) TO WS-BYTE
       PERFORM COMPLEMENT
       MOVE WS-BYTE TO SQ(WS-I)
       MOVE WS-A    TO SQ(WS-J)
       ADD 1 TO WS-I
       SUBTRACT 1 FROM WS-J
    END-PERFORM
    IF WS-I = WS-J
       MOVE SQ(WS-I) TO WS-BYTE
       PERFORM COMPLEMENT
       MOVE WS-BYTE TO SQ(WS-I)
    END-IF

    *> Hand polynomial hash over each character: h = (h*31 + ascii) mod 1e9+7.
    MOVE 0 TO WS-H
    PERFORM VARYING WS-K FROM 1 BY 1 UNTIL WS-K > WS-L
       MOVE SQ(WS-K) TO WS-BYTE
       COMPUTE WS-CODE = FUNCTION ORD(WS-BYTE) - 1
       COMPUTE WS-H = FUNCTION MOD(WS-H * 31 + WS-CODE, 1000000007)
    END-PERFORM

    MOVE WS-H TO ED-CK
    MOVE WS-L TO ED-N
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "reverse-complement(" FUNCTION TRIM(ED-N) ")"
    STOP RUN.

*> A<->T, C<->G; only A/C/G/T occur. Mirrors C's comp() chain.
COMPLEMENT.
    EVALUATE WS-BYTE
       WHEN "A"
          MOVE "T" TO WS-BYTE
       WHEN "C"
          MOVE "G" TO WS-BYTE
       WHEN "G"
          MOVE "C" TO WS-BYTE
       WHEN OTHER
          MOVE "A" TO WS-BYTE
    END-EVALUATE.
