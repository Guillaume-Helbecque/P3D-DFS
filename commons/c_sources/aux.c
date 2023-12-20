#include "../c_headers/aux.h"

// Swap two integers
void swap(int *a, int *b)
{
    int tmp = *b;
    *b = *a;
    *a = tmp;
}
