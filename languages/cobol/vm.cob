>>SOURCE FORMAT FREE
*> vm: a tiny stack-based bytecode virtual machine - interpreter dispatch.
*> Faithful port of languages/c/vm.c. Executes the FIXED 40-int PROG (embedded
*> verbatim) that computes acc=(acc*31+i*i) mod 2^32 over i in 0..N-1. 64-bit
*> stack/locals (COMP-5); MUL product masked to 2^32 with FUNCTION MOD exactly
*> where the C ref does. Output: line 1 = result mod 1e9+7, line 2 = vm(n).
*> Native ELF via cobc -> bit-exact under qemu+insn.
IDENTIFICATION DIVISION.
PROGRAM-ID. vm.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            PIC S9(18) COMP-5 VALUE 800000.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 PROG-T.
   05 FILLER       PIC S9(9) COMP-5 VALUE 0.
   05 FILLER       PIC S9(9) COMP-5 VALUE 0.
   05 FILLER       PIC S9(9) COMP-5 VALUE 2.
   05 FILLER       PIC S9(9) COMP-5 VALUE 0.
   05 FILLER       PIC S9(9) COMP-5 VALUE 0.
   05 FILLER       PIC S9(9) COMP-5 VALUE 0.
   05 FILLER       PIC S9(9) COMP-5 VALUE 2.
   05 FILLER       PIC S9(9) COMP-5 VALUE 1.
   05 FILLER       PIC S9(9) COMP-5 VALUE 1.
   05 FILLER       PIC S9(9) COMP-5 VALUE 0.
   05 FILLER       PIC S9(9) COMP-5 VALUE 1.
   05 FILLER       PIC S9(9) COMP-5 VALUE 2.
   05 FILLER       PIC S9(9) COMP-5 VALUE 6.
   05 FILLER       PIC S9(9) COMP-5 VALUE 7.
   05 FILLER       PIC S9(9) COMP-5 VALUE 37.
   05 FILLER       PIC S9(9) COMP-5 VALUE 1.
   05 FILLER       PIC S9(9) COMP-5 VALUE 1.
   05 FILLER       PIC S9(9) COMP-5 VALUE 0.
   05 FILLER       PIC S9(9) COMP-5 VALUE 31.
   05 FILLER       PIC S9(9) COMP-5 VALUE 4.
   05 FILLER       PIC S9(9) COMP-5 VALUE 1.
   05 FILLER       PIC S9(9) COMP-5 VALUE 0.
   05 FILLER       PIC S9(9) COMP-5 VALUE 1.
   05 FILLER       PIC S9(9) COMP-5 VALUE 0.
   05 FILLER       PIC S9(9) COMP-5 VALUE 4.
   05 FILLER       PIC S9(9) COMP-5 VALUE 3.
   05 FILLER       PIC S9(9) COMP-5 VALUE 2.
   05 FILLER       PIC S9(9) COMP-5 VALUE 1.
   05 FILLER       PIC S9(9) COMP-5 VALUE 1.
   05 FILLER       PIC S9(9) COMP-5 VALUE 0.
   05 FILLER       PIC S9(9) COMP-5 VALUE 0.
   05 FILLER       PIC S9(9) COMP-5 VALUE 1.
   05 FILLER       PIC S9(9) COMP-5 VALUE 3.
   05 FILLER       PIC S9(9) COMP-5 VALUE 2.
   05 FILLER       PIC S9(9) COMP-5 VALUE 0.
   05 FILLER       PIC S9(9) COMP-5 VALUE 8.
   05 FILLER       PIC S9(9) COMP-5 VALUE 8.
   05 FILLER       PIC S9(9) COMP-5 VALUE 1.
   05 FILLER       PIC S9(9) COMP-5 VALUE 1.
   05 FILLER       PIC S9(9) COMP-5 VALUE 9.
01 PROG-R REDEFINES PROG-T.
   05 PROG         PIC S9(9) COMP-5 OCCURS 40 TIMES.
01 STACK-T.
   05 STK          PIC S9(18) COMP-5 OCCURS 64 TIMES.
01 LOCALS-T.
   05 LOC          PIC S9(18) COMP-5 OCCURS 3 TIMES.
01 WS-SP           PIC S9(9)  COMP-5 VALUE 0.
01 WS-PC           PIC S9(9)  COMP-5 VALUE 0.
01 WS-OP           PIC S9(9)  COMP-5.
01 WS-A            PIC S9(18) COMP-5.
01 WS-B            PIC S9(18) COMP-5.
01 WS-C            PIC S9(18) COMP-5.
01 WS-RESULT       PIC S9(18) COMP-5 VALUE 0.
01 WS-OUT          PIC S9(18) COMP-5.
01 WS-RUNNING      PIC 9              VALUE 1.
01 MASK32          PIC S9(18) COMP-5 VALUE 4294967296.
01 MODP            PIC S9(18) COMP-5 VALUE 1000000007.
01 ED-CK           PIC -(18)9.
01 ED-N            PIC -(18)9.
PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF

    *> locals[0]=0, locals[1]=0, locals[2]=N ; pc=0 ; sp=0
    MOVE 0    TO LOC(1)
    MOVE 0    TO LOC(2)
    MOVE WS-N TO LOC(3)
    MOVE 0    TO WS-SP
    MOVE 0    TO WS-PC

    PERFORM UNTIL WS-RUNNING = 0
       *> op = PROG[pc++]
       MOVE PROG(WS-PC + 1) TO WS-OP
       ADD 1 TO WS-PC
       EVALUATE WS-OP
          WHEN 0
             *> PUSH imm: stack[sp++]=PROG[pc++]
             ADD 1 TO WS-SP
             MOVE PROG(WS-PC + 1) TO STK(WS-SP)
             ADD 1 TO WS-PC
          WHEN 1
             *> LOAD slot: stack[sp++]=locals[PROG[pc++]]
             ADD 1 TO WS-SP
             MOVE LOC(PROG(WS-PC + 1) + 1) TO STK(WS-SP)
             ADD 1 TO WS-PC
          WHEN 2
             *> STORE slot: locals[PROG[pc++]]=stack[--sp]
             MOVE STK(WS-SP) TO LOC(PROG(WS-PC + 1) + 1)
             SUBTRACT 1 FROM WS-SP
             ADD 1 TO WS-PC
          WHEN 3
             *> ADD: b=stack[--sp],a=stack[--sp]; stack[sp++]=(a+b)&MASK
             MOVE STK(WS-SP) TO WS-B
             SUBTRACT 1 FROM WS-SP
             MOVE STK(WS-SP) TO WS-A
             SUBTRACT 1 FROM WS-SP
             COMPUTE WS-C = FUNCTION MOD(WS-A + WS-B, MASK32)
             ADD 1 TO WS-SP
             MOVE WS-C TO STK(WS-SP)
          WHEN 4
             *> MUL: stack[sp++]=(a*b)&MASK  (64-bit product before mask)
             MOVE STK(WS-SP) TO WS-B
             SUBTRACT 1 FROM WS-SP
             MOVE STK(WS-SP) TO WS-A
             SUBTRACT 1 FROM WS-SP
             COMPUTE WS-C = FUNCTION MOD(WS-A * WS-B, MASK32)
             ADD 1 TO WS-SP
             MOVE WS-C TO STK(WS-SP)
          WHEN 5
             *> SUB: stack[sp++]=(a-b)&MASK
             MOVE STK(WS-SP) TO WS-B
             SUBTRACT 1 FROM WS-SP
             MOVE STK(WS-SP) TO WS-A
             SUBTRACT 1 FROM WS-SP
             COMPUTE WS-C = FUNCTION MOD(WS-A - WS-B, MASK32)
             ADD 1 TO WS-SP
             MOVE WS-C TO STK(WS-SP)
          WHEN 6
             *> LT: stack[sp++]=(a<b)?1:0
             MOVE STK(WS-SP) TO WS-B
             SUBTRACT 1 FROM WS-SP
             MOVE STK(WS-SP) TO WS-A
             SUBTRACT 1 FROM WS-SP
             ADD 1 TO WS-SP
             IF WS-A < WS-B
                MOVE 1 TO STK(WS-SP)
             ELSE
                MOVE 0 TO STK(WS-SP)
             END-IF
          WHEN 7
             *> JZ addr: c=stack[--sp]; if c==0 pc=PROG[pc] else pc++
             MOVE STK(WS-SP) TO WS-C
             SUBTRACT 1 FROM WS-SP
             IF WS-C = 0
                MOVE PROG(WS-PC + 1) TO WS-PC
             ELSE
                ADD 1 TO WS-PC
             END-IF
          WHEN 8
             *> JMP addr: pc=PROG[pc]
             MOVE PROG(WS-PC + 1) TO WS-PC
          WHEN 9
             *> HALT: result=stack[sp-1]; break
             MOVE STK(WS-SP) TO WS-RESULT
             MOVE 0 TO WS-RUNNING
       END-EVALUATE
    END-PERFORM

    COMPUTE WS-OUT = FUNCTION MOD(WS-RESULT, MODP)
    MOVE WS-OUT TO ED-CK
    MOVE WS-N   TO ED-N
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "vm(" FUNCTION TRIM(ED-N) ")"
    STOP RUN.
