/*
  This files is derived from the UTS repository of Dinan et al at:
  https://sourceforge.net/projects/uts-benchmark/

  Reference:
    S. Olivier, J. Huan, J. Liu, et al. (2007) UTS: An Unbalanced Tree Search
    Benchmark. 19th International Workshop on Languages and Compilers for Parallel
    Computing (LCPC). DOI: 10.1007/978-3-540-72521-3_18.
*/

#ifndef _UTS_H
#define _UTS_H

#ifdef __cplusplus
extern "C" {
#endif

#include "rng.h"

/***********************************************************
 *  Tree node descriptor                                   *
 ***********************************************************/

#define MAXNUMCHILDREN 100  // cap on children (BIN root is exempt)

typedef struct
{
  int dist;             // distribution governing number of children
  int height;           // depth of this node in the tree
  int numChildren;      // number of children, -1 => not yet determined

  struct state_t state; // RNG state associated with this node
} Node_UTS;

/* Tree type
 *   Trees are generated using a Galton-Watson process, in
 *   which the branching factor of each node is a random
 *   variable.
 *
 *   The random variable can follow a binomial distribution
 *   or a geometric distribution.  Hybrid tree are
 *   generated with geometric distributions near the
 *   root and binomial distributions towards the leaves.
 */
enum uts_trees_e    { BIN = 0, GEO, HYBRID, BALANCED };
enum uts_geoshape_e { LINEAR = 0, EXPDEC, CYCLIC, FIXED };

typedef enum uts_trees_e tree_t;
typedef enum uts_geoshape_e geoshape_t;

/* Strings for the above enums */
extern char* uts_trees_str[];
extern char* uts_geoshapes_str[];

/* Utility Functions */
#define MAX(a,b) (((a) > (b)) ? (a) : (b))

double rng_toProb(int n);

/* Common tree routines */
void uts_initRoot(Node_UTS* root, tree_t treeType, int rootId);

int uts_numChildren_bin(Node_UTS* parent, int nonLeafBF, double nonLeafProb);
int uts_numChildren_geo(Node_UTS* parent, double b_0, geoshape_t shape_fn, int gen_mx);
int uts_numChildren(Node_UTS* parent, tree_t treeType, int nonLeafBF, double nonLeafProb,
  double b_0, geoshape_t shape_fn, int gen_mx, double shiftDepth);

int uts_childType(Node_UTS* parent, tree_t treeType, double shiftDepth, int gen_mx);

void c_decompose(Node_UTS* parent, Node_UTS children[], tree_t treeType, int numChildren,
  int gen_mx, double shiftDepth, int computeGranularity, int* treeSize, int* maxDepth);

#ifdef __cplusplus
}
#endif

#endif /* _UTS_H */
