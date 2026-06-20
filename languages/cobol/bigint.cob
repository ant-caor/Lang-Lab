>>SOURCE FORMAT FREE
*> bigint: hand-rolled multi-precision N! in base-2^32 limbs, then poly-hash.
*> Faithful port of languages/c/bigint.c. NO native/library bignum: limbs live
*> in a PIC 9(18) COMP-5 OCCURS table (a 32-bit value needs 10 decimal digits,
*> so 9(9) is too small). Per limb: cur = limb*k + carry, store low 32 bits via
*> FUNCTION MOD(cur,2^32), carry = cur / 2^32 (integer truncating divide). cur
*> peaks below 2^45 (limb<2^32, k<=6000), well inside S9(18) COMP-5 (~2^63).
*> Output: line 1 = poly-hash checksum, line 2 = bigint(n).
*> Native ELF via cobc -> bit-exact under qemu+insn.
IDENTIFICATION DIVISION.
PROGRAM-ID. bigint.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            PIC S9(9)  COMP-5 VALUE 6000.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 LIMBS-T.
   05 LB           PIC 9(18)  COMP-5 OCCURS 6100 TIMES.
01 WS-LEN          PIC S9(9)  COMP-5 VALUE 1.
01 WS-K            PIC S9(9)  COMP-5.
01 WS-I            PIC S9(9)  COMP-5.
01 WS-CARRY        PIC 9(18)  COMP-5 VALUE 0.
01 WS-CUR          PIC 9(18)  COMP-5.
01 WS-LOW          PIC 9(18)  COMP-5.
01 WS-H            PIC S9(18) COMP-5 VALUE 0.
01 WS-BASE         PIC 9(18)  COMP-5 VALUE 4294967296.
01 WS-P            PIC S9(18) COMP-5 VALUE 1000000007.
01 ED-CK           PIC -(18)9.
01 ED-N            PIC Z(8)9.
PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF

    MOVE 1 TO WS-LEN
    MOVE 1 TO LB(1)

    PERFORM VARYING WS-K FROM 2 BY 1 UNTIL WS-K > WS-N
       MOVE 0 TO WS-CARRY
       PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-LEN
          COMPUTE WS-CUR = LB(WS-I) * WS-K + WS-CARRY
          COMPUTE WS-LOW = FUNCTION MOD(WS-CUR, WS-BASE)
          MOVE WS-LOW TO LB(WS-I)
          COMPUTE WS-CARRY = WS-CUR / WS-BASE
       END-PERFORM
       PERFORM UNTIL WS-CARRY = 0
          ADD 1 TO WS-LEN
          COMPUTE LB(WS-LEN) = FUNCTION MOD(WS-CARRY, WS-BASE)
          COMPUTE WS-CARRY = WS-CARRY / WS-BASE
       END-PERFORM
    END-PERFORM

    MOVE 0 TO WS-H
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-LEN
       COMPUTE WS-H = FUNCTION MOD(WS-H * 31 + LB(WS-I), WS-P)
    END-PERFORM

    MOVE WS-H TO ED-CK
    MOVE WS-N TO ED-N
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "bigint(" FUNCTION TRIM(ED-N) ")"
    STOP RUN.
