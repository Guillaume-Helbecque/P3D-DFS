/*
  This files is derived from the UTS repository of Dinan et al at:
  https://sourceforge.net/projects/uts-benchmark/

  Reference:
    S. Olivier, J. Huan, J. Liu, et al. (2007) UTS: An Unbalanced Tree Search
    Benchmark. 19th International Workshop on Languages and Compilers for Parallel
    Computing (LCPC). DOI: 10.1007/978-3-540-72521-3_18.
*/

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

#include "../c_headers/uts.h"

char* uts_trees_str[]     = { "Binomial", "Geometric", "Hybrid", "Balanced" };
char* uts_geoshapes_str[] = { "Linear decrease", "Exponential decrease", "Cyclic",
                              "Fixed branching factor" };

/***********************************************************
 *                                                         *
 *  FUNCTIONS                                              *
 *                                                         *
 ***********************************************************/

// Interpret 32 bit positive integer as value on [0,1)
double rng_toProb(int n)
{
  if (n < 0)
    printf("*** toProb: rand n = %d out of range\n",n);

  return ((n<0)? 0.0 : ((double) n)/2147483648.0);
}

void uts_initRoot(Node_UTS* root, tree_t treeType, int rootId)
{
  root->dist = treeType;
  root->height = 0;
  root->numChildren = -1; // not yet determined
  rng_init(root->state.state, rootId);
}

int uts_numChildren_bin(Node_UTS* parent, int nonLeafBF, double nonLeafProb)
{
  // distribution is identical everywhere below root
  int    v = rng_rand(parent->state.state);
  double d = rng_toProb(v);

  return (d < nonLeafProb) ? nonLeafBF : 0;
}

int uts_numChildren_geo(Node_UTS* parent, double b_0, geoshape_t shape_fn, int gen_mx)
{
  double b_i = b_0;
  int depth = parent->height;

  // use shape function to compute target b_i
  if (depth > 0) {
    switch (shape_fn) {

      // expected size polynomial in depth
      case EXPDEC:
        b_i = b_0 * pow((double) depth, -log(b_0)/log((double) gen_mx));
        break;

      // cyclic tree size
      case CYCLIC:
        if (depth > 5 * gen_mx) {
          b_i = 0.0;
          break;
        }
        b_i = pow(b_0, sin(2.0*3.141592653589793*(double) depth / (double) gen_mx));
        break;

      // identical distribution at all nodes up to max depth
      case FIXED:
        b_i = (depth < gen_mx)? b_0 : 0;
        break;

      // linear decrease in b_i
      case LINEAR:

      default:
        b_i =  b_0 * (1.0 - (double) depth / (double) gen_mx);
        break;
    }
  }

  // given target b_i, find prob p so expected value of
  // geometric distribution is b_i.
  double p = 1.0 / (1.0 + b_i);

  // get uniform random number on [0,1)
  int h = rng_rand(parent->state.state);
  double u = rng_toProb(h);

  // max number of children at this cumulative probability
  // (from inverse geometric cumulative density function)
  int numChildren = (int) floor(log(1 - u) / log(1 - p));

  return numChildren;
}

int uts_numChildren(Node_UTS* parent, tree_t treeType, int nonLeafBF, double nonLeafProb,
  double b_0, geoshape_t shape_fn, int gen_mx, double shiftDepth)
{
  int numChildren;

  switch (treeType) {
    case BIN:
      if (parent->height == 0)
        numChildren = (int) floor(b_0);
      else
        numChildren = uts_numChildren_bin(parent, nonLeafBF, nonLeafProb);
      break;

    case GEO:
      numChildren = uts_numChildren_geo(parent, b_0, shape_fn, gen_mx);
      break;

    case HYBRID:
      if (parent->height < shiftDepth * gen_mx)
        numChildren = uts_numChildren_geo(parent, b_0, shape_fn, gen_mx);
      else
        numChildren = uts_numChildren_bin(parent, nonLeafBF, nonLeafProb);
      break;

    case BALANCED:
      if (parent->height < gen_mx)
        numChildren = (int) b_0;
      break;

    default:
      return -1;
  }

  // limit number of children
  // only a BIN root can have more than MAXNUMCHILDREN
  if (parent->height == 0 && parent->dist == BIN) {
    int rootBF = (int) ceil(b_0);
    if (numChildren > rootBF) {
      printf("*** Number of children of root truncated from %d to %d\n",
             numChildren, rootBF);
      numChildren = rootBF;
    }
  }
  else if (treeType != BALANCED) {
    if (numChildren > MAXNUMCHILDREN) {
      printf("*** Number of children truncated from %d to %d\n",
             numChildren, MAXNUMCHILDREN);
      numChildren = MAXNUMCHILDREN;
    }
  }

  return numChildren;
}

int uts_childType(Node_UTS* parent, tree_t treeType, double shiftDepth, int gen_mx)
{
  switch (treeType) {
    case BIN:
      return BIN;
    case GEO:
      return GEO;
    case HYBRID:
      if (parent->height < shiftDepth * gen_mx)
        return GEO;
      else
        return BIN;
    case BALANCED:
      return BALANCED;
    default:
      return -1;
  }
}

void c_decompose(Node_UTS* parent, Node_UTS children[], tree_t treeType, int numChildren,
  int gen_mx, double shiftDepth, int computeGranularity, int* treeSize, int* maxDepth)
{
  int childrenHeight = parent->height + 1;
  int childType = childType = uts_childType(parent, treeType, shiftDepth, gen_mx);

  for (int i = 0; i < numChildren; i++) {
    children[i].dist = childType;
    children[i].height = childrenHeight;
    children[i].numChildren = -1;

    // 'computeGranularity' controls the number of 'rng_spawn' calls per node evaluation.
    for (int j = 0; j < computeGranularity; j++) {
      rng_spawn(parent->state.state, children[i].state.state, i);
    }
  }

  *treeSize += numChildren;
  *maxDepth = MAX(*maxDepth, childrenHeight);
}
