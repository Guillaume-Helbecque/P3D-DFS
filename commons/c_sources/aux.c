#include "../c_headers/aux.h"
#include <limits.h>
#include <stdlib.h>
#include <stdio.h>

// Swap two integers
void swap(int *a, int *b)
{
    int tmp = *b;
    *b = *a;
    *a = tmp;
}

void save_time(const int numThreads, const double time, const char *path)
{
  FILE *f = fopen(path, "a");
  fprintf(f, "%d %f\n", numThreads, time);
  fclose(f);
}
