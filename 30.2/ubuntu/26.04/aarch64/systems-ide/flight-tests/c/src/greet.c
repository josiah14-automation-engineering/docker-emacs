#include "greet.h"
#include <stdio.h>

Greeting make_greeting(const char *name, int excitement) {
  Greeting g;
  g.name = name;
  g.excitement = excitement;
  return g;
}

void print_greeting(const Greeting *g) {
  for (int i = 0; i < g->excitement; i++) {
    printf("Hello, %s!\n", g->name);
  }
}
