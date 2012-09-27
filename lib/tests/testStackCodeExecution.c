
typedef void(*voidfn)(void);
int main(int argc, char *argv[]) {
    char a[12] = "aaaaaaaaaa";
    voidfn bad_function = (voidfn)a;
    bad_function();
    return 0;
}
