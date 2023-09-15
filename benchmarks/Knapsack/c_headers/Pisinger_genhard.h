#ifndef PISINGER_GENHARD_H
#define PISINGER_GENHARD_H

void srand48x(int s);

int lrand48x(void);

int isprime(int i);

int primelarger(int i);

long long generator(int n, int *pp, int *ww, int type, int r, int v, int tests);

#endif
