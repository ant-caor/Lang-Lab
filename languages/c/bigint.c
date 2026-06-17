// bigint: hand-rolled multi-precision arithmetic - the carry-propagation axis. Compute N! as an
// array of base-2^32 limbs by repeated bignum*smallint multiplication (each limb: cur = limb*k +
// carry; store low 32 bits, propagate the high bits), then poly-hash the limbs. Implemented by hand
// (NO native/library big integers - languages with built-in bignum must hand-roll too), so it
// measures raw multi-word arithmetic. All integer-deterministic.
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#define P 1000000007L
int main(int argc,char**argv){
    int N = argc>1?atoi(argv[1]):6000;
    uint32_t *limbs = malloc((size_t)(N+64)*sizeof(uint32_t));
    int len=1; limbs[0]=1;
    for(long k=2;k<=N;k++){
        uint64_t carry=0;
        for(int i=0;i<len;i++){
            uint64_t cur=(uint64_t)limbs[i]*(uint64_t)k + carry;
            limbs[i]=(uint32_t)(cur & 0xFFFFFFFF);
            carry=cur>>32;
        }
        while(carry>0){ limbs[len++]=(uint32_t)(carry & 0xFFFFFFFF); carry>>=32; }
    }
    long h=0;
    for(int i=0;i<len;i++) h=(h*31 + limbs[i])%P;
    printf("%ld\n",h); printf("bigint(%d)\n",N);
    return 0;
}
