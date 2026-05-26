#ifndef __BOUND_GLB__
#define __BOUND_GLB__

#include "utils.hpp"

// Hungarian algorithm for rectangular LAP (n workers, N jobs).
// Used by GLB and IGLB.
longint Hungarian_GLB(const vector<longint>&, int, int);

// GLB (Gilmore-Lawler Bound) — handles both square and rectangular instances
longint bound_GLB(const std::vector<int>& mapping,
                  const std::vector<bool>& available,
                  int depth,
                  const std::vector<int>& F,
                  const std::vector<int>& D,
                  int n, int N);

#endif
