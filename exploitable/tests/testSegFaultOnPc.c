// Note that some Linux kernels will indicate an si_addr of 0 when this test
// case executes, which may result in mis-classification
#include <string.h>
#include <stdlib.h>
#include <sys/mman.h>

typedef void(*voidfn)(void);
int main(int argc, char *argv[]) {
    char *a = valloc(64);
    mprotect(a, 64, PROT_WRITE);
    voidfn bad_function = (voidfn)a;
    memset(a, 0xff, 64);
    bad_function();
    return 0;
}
