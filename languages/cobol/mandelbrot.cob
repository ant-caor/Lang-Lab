>>SOURCE FORMAT FREE
*> mandelbrot: count in-set pixels over an N x N grid of [-1.5,0.5]x[-1.0,1.0].
*> Faithful port of languages/c/mandelbrot.c. IEEE-754 double via USAGE COMP-2.
*> FMA-proof: t = zr*zi then zi = t + t + ci (never a fused multiply-add), so the
*> result is bit-identical to the C reference. Output: line 1 = in-set count,
*> line 2 = mandelbrot(n). Native ELF via cobc -> bit-exact under qemu+insn.
IDENTIFICATION DIVISION.
PROGRAM-ID. mandelbrot.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            PIC S9(9)  COMP-5 VALUE 128.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 WS-COUNT        PIC S9(18) COMP-5 VALUE 0.
01 WS-X            PIC S9(9)  COMP-5.
01 WS-Y            PIC S9(9)  COMP-5.
01 WS-I            PIC S9(9)  COMP-5.
01 WS-CI           USAGE COMP-2.
01 WS-CR           USAGE COMP-2.
01 WS-ZR           USAGE COMP-2.
01 WS-ZI           USAGE COMP-2.
01 WS-TR           USAGE COMP-2.
01 WS-TI           USAGE COMP-2.
01 WS-T            USAGE COMP-2.
01 WS-ND           USAGE COMP-2.
01 ED-CK           PIC -(18)9.
01 ED-N            PIC Z(8)9.
PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF
    COMPUTE WS-ND = WS-N

    PERFORM VARYING WS-Y FROM 0 BY 1 UNTIL WS-Y >= WS-N
       COMPUTE WS-CI = 2.0E0 * WS-Y / WS-ND - 1.0E0
       PERFORM VARYING WS-X FROM 0 BY 1 UNTIL WS-X >= WS-N
          COMPUTE WS-CR = 2.0E0 * WS-X / WS-ND - 1.5E0
          MOVE 0.0E0 TO WS-ZR
          MOVE 0.0E0 TO WS-ZI
          MOVE 0.0E0 TO WS-TR
          MOVE 0.0E0 TO WS-TI
          MOVE 0    TO WS-I
          PERFORM UNTIL WS-I >= 50 OR WS-TR + WS-TI > 4.0E0
             COMPUTE WS-T  = WS-ZR * WS-ZI
             COMPUTE WS-ZI = WS-T + WS-T + WS-CI
             COMPUTE WS-ZR = WS-TR - WS-TI + WS-CR
             COMPUTE WS-TR = WS-ZR * WS-ZR
             COMPUTE WS-TI = WS-ZI * WS-ZI
             ADD 1 TO WS-I
          END-PERFORM
          IF WS-TR + WS-TI <= 4.0E0
             ADD 1 TO WS-COUNT
          END-IF
       END-PERFORM
    END-PERFORM

    MOVE WS-COUNT TO ED-CK
    MOVE WS-N     TO ED-N
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "mandelbrot(" FUNCTION TRIM(ED-N) ")"
    STOP RUN.
