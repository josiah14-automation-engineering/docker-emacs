#ifndef GREET_H
#define GREET_H

typedef struct {
    const char *name;
    int excitement;
} Greeting;

Greeting make_greeting(const char *name, int excitement);
void print_greeting(const Greeting *g);

#endif
