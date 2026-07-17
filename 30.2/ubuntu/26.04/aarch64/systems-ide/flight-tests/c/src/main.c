#include "greet.h"

int main(void) {
    int unused = 42;
    Greeting g = make_greeting("clangd", 3);
    print_greeting(&g);
    return 0;
}
