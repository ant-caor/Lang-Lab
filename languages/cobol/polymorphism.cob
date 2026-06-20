>>SOURCE FORMAT FREE
*> polymorphism: the dynamic-dispatch / virtual-call-overhead axis. Faithful port of
*> languages/c/polymorphism.c. Build N=10000 objects of K=6 concrete types in an
*> unpredictable (megamorphic) LCG order, then fold an accumulator through all of them
*> M passes: acc = obj.apply(acc). Each type has its OWN apply() formula (mod P=1e9+7);
*> which one runs is resolved at RUNTIME from the object's data. acc threads through
*> every call (a strict data dependency) so exactly N*M dispatches happen and the
*> checksum depends on M. Output: line 1 = final acc, line 2 = polymorphism(M).
*>
*> DISPATCH MECHANISM (the documented C/COBOL asymmetry, the fair analogue of a vtable):
*> C stores a function pointer per object; COBOL stores the per-object SUBPROGRAM NAME
*> (APPLY0..APPLY5) and the fold loop issues CALL WS-OBJ-NAME USING ... -- a dynamic,
*> runtime-resolved subprogram dispatch (CALL identifier, NOT a literal). This is a
*> genuine runtime-data-driven indirect call, NOT an EVALUATE/IF on a numeric type tag.
*> The six bodies are six separate PROGRAM-IDs (END PROGRAM separators) in this one .cob.
*> Native ELF via cobc -> bit-exact under qemu+insn.
IDENTIFICATION DIVISION.
PROGRAM-ID. polymorphism.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-M            PIC S9(9)  COMP-5 VALUE 50.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 WS-N            PIC S9(9)  COMP-5 VALUE 10000.
01 WS-K            PIC S9(9)  COMP-5 VALUE 6.
01 WS-S            PIC S9(18) COMP-5 VALUE 42.
01 WS-T            PIC S9(9)  COMP-5.
01 WS-TD           PIC 9.
01 WS-I            PIC S9(9)  COMP-5.
01 WS-PASS         PIC S9(9)  COMP-5.
01 WS-ACC          PIC S9(18) COMP-5 VALUE 1.
*> per-object store, in LCG generation order (megamorphic), 1-indexed
01 OBJ-T.
   05 OBJ-ENTRY    OCCURS 10000 TIMES.
      10 OBJ-NAME  PIC X(8).
      10 OBJ-A     PIC S9(18) COMP-5.
      10 OBJ-B     PIC S9(18) COMP-5.
      10 OBJ-C     PIC S9(18) COMP-5.
*> the per-object program name the dynamic CALL resolves at runtime
01 WS-OBJ-NAME     PIC X(8).
01 WS-X            PIC S9(18) COMP-5.
01 WS-A            PIC S9(18) COMP-5.
01 WS-B            PIC S9(18) COMP-5.
01 WS-C            PIC S9(18) COMP-5.
01 ED-ACC          PIC -(18)9.
01 ED-M            PIC -(9)9.
PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-M = FUNCTION NUMVAL(WS-ARG)
    END-IF

    *> build N objects: type from the LCG HIGH bits (low bits correlate), all K used;
    *> fields a,b,c = next LCG values mod 1000; kept in generation order.
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
       PERFORM LCG-STEP
       COMPUTE WS-T = FUNCTION MOD(WS-S / 65536, WS-K)
       MOVE WS-T TO WS-TD
       STRING "APPLY" DELIMITED BY SIZE
              WS-TD   DELIMITED BY SIZE
              INTO OBJ-NAME(WS-I)
       END-STRING
       PERFORM LCG-STEP
       COMPUTE OBJ-A(WS-I) = FUNCTION MOD(WS-S, 1000)
       PERFORM LCG-STEP
       COMPUTE OBJ-B(WS-I) = FUNCTION MOD(WS-S, 1000)
       PERFORM LCG-STEP
       COMPUTE OBJ-C(WS-I) = FUNCTION MOD(WS-S, 1000)
    END-PERFORM

    *> fold acc through every object, M passes; DYNAMIC dispatch per object via
    *> CALL WS-OBJ-NAME (the name held in the object) -> runtime-resolved subprogram.
    MOVE 1 TO WS-ACC
    PERFORM VARYING WS-PASS FROM 1 BY 1 UNTIL WS-PASS > WS-M
       PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
          MOVE OBJ-NAME(WS-I) TO WS-OBJ-NAME
          MOVE WS-ACC         TO WS-X
          MOVE OBJ-A(WS-I)    TO WS-A
          MOVE OBJ-B(WS-I)    TO WS-B
          MOVE OBJ-C(WS-I)    TO WS-C
          CALL WS-OBJ-NAME USING WS-X WS-A WS-B WS-C
          MOVE WS-X TO WS-ACC
       END-PERFORM
    END-PERFORM

    MOVE WS-ACC TO ED-ACC
    MOVE WS-M   TO ED-M
    DISPLAY FUNCTION TRIM(ED-ACC)
    DISPLAY "polymorphism(" FUNCTION TRIM(ED-M) ")"
    STOP RUN.

*> LCG: s = (s * 1103515245 + 12345) & 0x7fffffff. The product (<2.31e9 * 1.10e9 ~
*> 2.5e18) fits S9(18) signed 64-bit; the mask is MOD by 2^31 on the non-negative value.
LCG-STEP.
    COMPUTE WS-S = FUNCTION MOD(WS-S * 1103515245 + 12345, 2147483648).
END PROGRAM polymorphism.

*> ---------------------------------------------------------------------------
*> The six "virtual method" bodies. Each is a separate PROGRAM-ID resolved by name at
*> runtime through CALL identifier. Each takes USING x a b c and returns the per-type
*> formula in x (x is BY REFERENCE -> the caller reads the result back from WS-X).
IDENTIFICATION DIVISION.
PROGRAM-ID. APPLY0.
DATA DIVISION.
LINKAGE SECTION.
01 LK-X            PIC S9(18) COMP-5.
01 LK-A            PIC S9(18) COMP-5.
01 LK-B            PIC S9(18) COMP-5.
01 LK-C            PIC S9(18) COMP-5.
PROCEDURE DIVISION USING LK-X LK-A LK-B LK-C.
    COMPUTE LK-X = FUNCTION MOD(LK-X * 1000003 + LK-A, 1000000007)
    EXIT PROGRAM.
END PROGRAM APPLY0.

IDENTIFICATION DIVISION.
PROGRAM-ID. APPLY1.
DATA DIVISION.
LINKAGE SECTION.
01 LK-X            PIC S9(18) COMP-5.
01 LK-A            PIC S9(18) COMP-5.
01 LK-B            PIC S9(18) COMP-5.
01 LK-C            PIC S9(18) COMP-5.
PROCEDURE DIVISION USING LK-X LK-A LK-B LK-C.
    COMPUTE LK-X = FUNCTION MOD(LK-X * 998273 + LK-B, 1000000007)
    EXIT PROGRAM.
END PROGRAM APPLY1.

IDENTIFICATION DIVISION.
PROGRAM-ID. APPLY2.
DATA DIVISION.
LINKAGE SECTION.
01 LK-X            PIC S9(18) COMP-5.
01 LK-A            PIC S9(18) COMP-5.
01 LK-B            PIC S9(18) COMP-5.
01 LK-C            PIC S9(18) COMP-5.
PROCEDURE DIVISION USING LK-X LK-A LK-B LK-C.
    COMPUTE LK-X = FUNCTION MOD(LK-X * 999983 + LK-C, 1000000007)
    EXIT PROGRAM.
END PROGRAM APPLY2.

IDENTIFICATION DIVISION.
PROGRAM-ID. APPLY3.
DATA DIVISION.
LINKAGE SECTION.
01 LK-X            PIC S9(18) COMP-5.
01 LK-A            PIC S9(18) COMP-5.
01 LK-B            PIC S9(18) COMP-5.
01 LK-C            PIC S9(18) COMP-5.
PROCEDURE DIVISION USING LK-X LK-A LK-B LK-C.
    COMPUTE LK-X = FUNCTION MOD(LK-X * 997879 + LK-A + LK-B, 1000000007)
    EXIT PROGRAM.
END PROGRAM APPLY3.

IDENTIFICATION DIVISION.
PROGRAM-ID. APPLY4.
DATA DIVISION.
LINKAGE SECTION.
01 LK-X            PIC S9(18) COMP-5.
01 LK-A            PIC S9(18) COMP-5.
01 LK-B            PIC S9(18) COMP-5.
01 LK-C            PIC S9(18) COMP-5.
PROCEDURE DIVISION USING LK-X LK-A LK-B LK-C.
    COMPUTE LK-X = FUNCTION MOD(LK-X * 996323 + LK-B * LK-C, 1000000007)
    EXIT PROGRAM.
END PROGRAM APPLY4.

IDENTIFICATION DIVISION.
PROGRAM-ID. APPLY5.
DATA DIVISION.
LINKAGE SECTION.
01 LK-X            PIC S9(18) COMP-5.
01 LK-A            PIC S9(18) COMP-5.
01 LK-B            PIC S9(18) COMP-5.
01 LK-C            PIC S9(18) COMP-5.
PROCEDURE DIVISION USING LK-X LK-A LK-B LK-C.
    COMPUTE LK-X = FUNCTION MOD(LK-X * 995369 + LK-A + LK-C, 1000000007)
    EXIT PROGRAM.
END PROGRAM APPLY5.
