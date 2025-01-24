/* ======================================================================
				   macros
   ====================================================================== */

// #define srand(x)     srand48x(x)
// #define randm(x)    (lrand48x() % (long) (x))
//
// typedef int boolean;
// #define TRUE 1
// #define FALSE 0
//
// #define SPAN  10
// #define SPAN2  5


/* =======================================================================
                                random
   ======================================================================= */

/* to generate the same instances as at HP9000 - UNIX, */
/* here follows C-versions of SRAND48, and LRAND48.  */

// unsigned int  _h48, _l48;

void srand48x(int  s);

int  lrand48x(void);


int isprime(int i);


int primelarger(int i);


/* ======================================================================
                                generator
   ====================================================================== */

long long generator(int n, int *pp, int *ww, int type, int r, int v, int tests);


/* ======================================================================
                                showitems
   ====================================================================== */

void showitems(int n, int *pp, int *ww, long long c);
