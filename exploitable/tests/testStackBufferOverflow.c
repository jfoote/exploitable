#include <string.h>
#include <stdio.h>

int i;

void overflow() {
    char a[1];
    for (i = 0; i< 30; i++) {
        a[i] = 'A';
    }
    printf("%s\n", a);
}

int main(int argc, char *argv[]) {
    overflow();
}
