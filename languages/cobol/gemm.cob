>>SOURCE FORMAT FREE
*> gemm: quantized integer matrix-multiply - the dominant ML inference kernel.
*> Square matmul of side N (N x N matrices). Pinned loop order i,k,j so B is
*> accessed row-sequentially. LCG (state*1103515245+12345 mod 2^31) fills A
*> then B with values 0..127. C cells are 64-bit accumulators. No BLAS.
*> Checksum = poly-hash of C row-major mod 1e9+7. Secondary = C[N*N-1] mod P.
*> Max N=256 => N*N=65536 cells. PIC S9(18) COMP-5 for 64-bit values.
IDENTIFICATION DIVISION.
PROGRAM-ID. gemm.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            PIC S9(9)  COMP-5 VALUE 256.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 WS-NN           PIC S9(9)  COMP-5.
*> A and B: up to 256*256 = 65536 entries, values 0..127
01 A-T.
   05 A-ARR        PIC S9(9)  COMP-5 OCCURS 65536 TIMES.
01 B-T.
   05 B-ARR        PIC S9(9)  COMP-5 OCCURS 65536 TIMES.
*> C: up to 65536 entries; cell max = N*127*127 ~= 4.2M (fits S9(9)), but
*> using S9(18) to be safe with 64-bit accumulation requirement.
01 C-T.
   05 C-ARR        PIC S9(18) COMP-5 OCCURS 65536 TIMES.
01 WS-S            PIC S9(18) COMP-5 VALUE 42.
01 WS-IDX          PIC S9(9)  COMP-5.
01 WS-I            PIC S9(9)  COMP-5.
01 WS-K            PIC S9(9)  COMP-5.
01 WS-J            PIC S9(9)  COMP-5.
01 WS-A-VAL        PIC S9(9)  COMP-5.
01 WS-KN           PIC S9(9)  COMP-5.
01 WS-BASE         PIC S9(9)  COMP-5.
01 WS-PROD         PIC S9(18) COMP-5.
01 WS-H            PIC S9(18) COMP-5 VALUE 0.
01 WS-CVAL         PIC S9(18) COMP-5.
01 WS-SEC          PIC S9(18) COMP-5.
01 ED-CK           PIC -(18)9.
01 ED-N            PIC Z(8)9.
01 ED-SEC          PIC -(18)9.
PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF

    COMPUTE WS-NN = WS-N * WS-N

    *> Fill A: state = lcg(state); A[i] = state mod 128
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > WS-NN
       COMPUTE WS-S = FUNCTION MOD(
           WS-S * 1103515245 + 12345, 2147483648)
       COMPUTE A-ARR(WS-IDX) = FUNCTION MOD(WS-S, 128)
    END-PERFORM

    *> Fill B: state = lcg(state); B[i] = state mod 128
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > WS-NN
       COMPUTE WS-S = FUNCTION MOD(
           WS-S * 1103515245 + 12345, 2147483648)
       COMPUTE B-ARR(WS-IDX) = FUNCTION MOD(WS-S, 128)
    END-PERFORM

    *> Zero C
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > WS-NN
       MOVE 0 TO C-ARR(WS-IDX)
    END-PERFORM

    *> Triple loop i, k, j (0-based; COBOL arrays 1-indexed, so +1 everywhere)
    PERFORM VARYING WS-I FROM 0 BY 1 UNTIL WS-I >= WS-N
       PERFORM VARYING WS-K FROM 0 BY 1 UNTIL WS-K >= WS-N
          COMPUTE WS-A-VAL = A-ARR(WS-I * WS-N + WS-K + 1)
          COMPUTE WS-KN    = WS-K * WS-N
          COMPUTE WS-BASE  = WS-I * WS-N
          PERFORM VARYING WS-J FROM 0 BY 1 UNTIL WS-J >= WS-N
             COMPUTE WS-PROD = WS-A-VAL * B-ARR(WS-KN + WS-J + 1)
             COMPUTE C-ARR(WS-BASE + WS-J + 1) =
                 C-ARR(WS-BASE + WS-J + 1) + WS-PROD
          END-PERFORM
       END-PERFORM
    END-PERFORM

    *> Checksum: h = (h*31 + C[i] mod P) mod P  row-major
    MOVE 0 TO WS-H
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > WS-NN
       COMPUTE WS-CVAL = FUNCTION MOD(C-ARR(WS-IDX), 1000000007)
       COMPUTE WS-H = FUNCTION MOD(WS-H * 31 + WS-CVAL, 1000000007)
    END-PERFORM

    *> Secondary: C[N*N-1] mod P (the bottom-right cell)
    COMPUTE WS-SEC = FUNCTION MOD(C-ARR(WS-NN), 1000000007)

    MOVE WS-H   TO ED-CK
    MOVE WS-N   TO ED-N
    MOVE WS-SEC TO ED-SEC
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "gemm(" FUNCTION TRIM(ED-N) ") = " FUNCTION TRIM(ED-SEC)
    STOP RUN.
