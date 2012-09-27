// Note that on some platforms, this test may may not cause a signal to be
// raised until the program counter is deferenced (instead of raising a
// signal on the return instruction). The test case will likely still be
// classified as EXPLOITABLE but will not be tagged with ReturnAv.
#include <stdio.h>
#if defined (__x86_64__)
    #define WORD_SIZE 8
#else
    #define WORD_SIZE 4
#endif

int i;

int the_overflow() {
    char a[WORD_SIZE];

    for (i = 0; i < WORD_SIZE*4; i++) {
        a[i] = (char)0xff;
    }
    return 0;
}

int main(int argc, char *argv[]) {
    the_overflow();
    return 0;
}
