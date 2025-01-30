/* Source: http://hjemmesider.diku.dk/~pisinger/genhard.c
 *
 * Archives containing instances' data:
 *    http://hjemmesider.diku.dk/~pisinger/smallcoeff_pisinger.tgz
 *    http://hjemmesider.diku.dk/~pisinger/largecoeff_pisinger.tgz
 *    http://hjemmesider.diku.dk/~pisinger/hardinstances_pisinger.tgz
 */

/* ======================================================================
	     genhard.c, David Pisinger   2002, jan 2004
   ====================================================================== */

/* This is a test generator from the paper:
 *
 *   D. Pisinger,
 *   Where are the hard knapsack problems
 *   Computers & Operations Research (2005)
 *
 * The current code generates randomly generated instances and
 * writes them to a file. Different capacities are considered
 * to ensure proper testing.
 *
 * The code conforms with the ANSI-C standard.
 *
 * The code is run by issuing the command
 *
 *   genhard n r type i S
 *
 * where n: number of items,
 *       r: range of coefficients,
 *       type: 1=uncorrelated, 2=weakly corr, 3=strongly corr,
 *             4=inverse str.corr, 5=almost str.corr, 6=subset-sum,
 *             7=even-odd subset-sum, 8=even-odd knapsack,
 *             9=uncorrelated, similar weights,
 *           11=uncorr. span(2,10)
 *           12=weak. corr. span(2,10)
 *           13=str. corr. span(2,10)
 *           14=mstr(3R/10,2R/10,6)
 *           15=pceil(3)
 *           16=circle(2/3)
 *       i: instance no
 *       S: number of tests in series (typically 1000)
 *
 * output will be written to the file "test.in".
 * format of output is
 *     n
 *     0 p[0] w[0]
 *     1 p[1] w[1]
 *     :
 *     n-1 p[n-1] w[n-1]
 *     c
 *
 *   (c) David Pisinger,
 *   DIKU, University of Copenhagen,
 *   Universitetsparken 1,
 *   DK-2100 Copenhagen.
 *   e-mail: pisinger@diku.dk
 */

#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <stdarg.h>
#include <values.h>
#include <string.h>
#include <math.h>


/* ======================================================================
				   macros
   ====================================================================== */

#define srand(x)     srand48x(x)
#define randm(x)    (lrand48x() % (long) (x))

typedef int boolean;
#define TRUE 1
#define FALSE 0

#define SPAN  10
#define SPAN2  5


/* =======================================================================
                                random
   ======================================================================= */

/* to generate the same instances as at HP9000 - UNIX, */
/* here follows C-versions of SRAND48, and LRAND48.  */

unsigned int  _h48, _l48;

void srand48x(int  s)
{
  _h48 = s;
  _l48 = 0x330E;
}

int  lrand48x(void)
{
  _h48 = (_h48 * 0xDEECE66D) + (_l48 * 0x5DEEC);
  _l48 = _l48 * 0xE66D + 0xB;
  _h48 = _h48 + (_l48 >> 16);
  _l48 = _l48 & 0xFFFF;
  return (_h48 >> 1);
}


/* ======================================================================
                                generator
   ====================================================================== */

long long generator(int n, int *pp, int *ww, int type, int r, int v, int tests)
{
  int i, p, w, r1, r2, k1, k2;
  long long wsum, psum, c;
  FILE *out;
  int sp[100], sw[100], span;

  /* printf("generator %d %d %d %d %d\n", n, type, r, v, tests); */
  srand(v);
  r1 = r / 10;
  r2 = r / 2;
  wsum = 0;
  span = 0;
  if (type == 11) span = 2;
  if (type == 12) span = 2;
  if (type == 13) span = 2;
  for (i = 0; i < span; i++) {
    sw[i] = randm(r) + 1;
    if (type == 11) sp[i] = randm(r) + 1;                /* uncorr */
    if (type == 12) sp[i] = randm(2*r1+1)+sw[i]-r1;      /* wekcorr */
    if (type == 13) sp[i] = sw[i] + r1;                  /* strcorr */
    if (sp[i] <= 0) sp[i] = 1;
    sw[i] = (sw[i] + SPAN2 - 1) / SPAN2;
    sp[i] = (sp[i] + SPAN2 - 1) / SPAN2;
  }
  for (i = 0; i < n; ) {
    w = randm(r) + 1;
    switch (type) {
      case  1: p = randm(r) + 1; /* uncorrelated */
               break;
      case  2: p = randm(2*r1+1) + w - r1; /* weakly corr */
               if (p <= 0) p = 1;
               break;
      case  3: p = w + r1;   /* strongly corr */
               break;
      case  4: p = w; /* inverse strongly corr */
               w = p + r1;
               break;
      case  5: p = w + r1 + randm(2*r/1000+1) - r/1000; /* alm str.corr */
               break;
      case  6: p = w; /* subset sum */
               break;
      case  7: w = 2*((w + 1)/2); /* even-odd */
               p = w;
               break;
      case  8: w = 2*((w + 1)/2); /* even-odd knapsack */
               p = w + r1;
               break;
      case  9: p = w; /* uncorrelated, similar weights */
               w = randm(r1) + 100*r;
               break;

      case 11:
      case 12:
      case 13:
               k1 = randm(10)+1;
               k2 = randm(span);
               w = k1 * sw[k2];
               p = k1 * sp[k2];
               break;
      case 14: w = randm(r)+1; p = w; /* slightly difficult */
               if (w % 6 == 0) { p += 3*r1; break; }
               p += 2*r1;
               break;
      case 15: w = randm(r)+1; p = 3*((w+2)/3);    /* even-odd like profits */
               break;
      case 16: w = randm(r)+1; p = 2*sqrt(4*r*r - (w-2*r)*(w-2*r))/3;
               break;

      default: fprintf(stderr, "undefined problem type (--t)\n");
               exit(1);
    }
    pp[i] = p; ww[i] = w; i++;
  }

  wsum = 0; psum = 0;
  for (i = 0; i < n; i++) {
    wsum += ww[i]; psum += pp[i];
  }
  c = (v * (long long) wsum) / (tests + 1);
  for (i = 0; i < n; i++) if (ww[i] > c) c = ww[i];

  switch (type) {
    case  1: return c;
    case  2: return c;
    case  3: return c;
    case  4: return c;
    case  5: return c;
    case  6: return c;
    case  7: return 2*(c/2) + 1;
    case  8: return 2*(c/2) + 1;
    case  9: return c;

    case 11: return c;
    case 12: return c;
    case 13: return c;
    case 14: return c;
    case 15: return c;
    case 16: return c;

    default: fprintf(stderr, "undefined problem type (--t)\n");
             exit(1);
  }
}
