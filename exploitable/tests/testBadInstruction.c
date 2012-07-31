#include <string.h>
#include <stdlib.h>
#include <sys/mman.h>

// Note that on some platforms this test will generate a SIGSEGV rather than
// a SIGILL, which will likely still be classified as EXPLOITABLE but will not
// be tagged with BadInstruction

typedef void(*voidfn)(void);
int main(int argc, char *argv[]) {
    char *a = valloc(64);
    mprotect(a, 64, PROT_READ | PROT_WRITE | PROT_EXEC);
    voidfn bad_function = (voidfn)a;
    memset(a, 0xff, 64);
    bad_function();
    return 0;
}
