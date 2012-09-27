// Note that on some operating systems this test case may simply be tagged
// as an AbortSignal if heap failure symbols are not available in the
// crash backtrace

#include <string.h>
#include <stdlib.h>

typedef void(*voidfn)(void);
int main(int argc, char *argv[]) {
    char *a = malloc(64);
    memset(a, 'A', 1024);
    free(a);
    return 0;
}
