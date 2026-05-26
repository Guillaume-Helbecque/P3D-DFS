#ifndef __BOUND_IGLB__
#define __BOUND_IGLB__

#include "utils.hpp"

// IGLB (Improved Gilmore-Lawler Bound) with secondary LAP
longint bound_IGLB(const std::vector<int>& mapping,
                   const std::vector<bool>& available,
                   int depth,
                   const std::vector<int>& F,
                   const std::vector<int>& D,
                   int n, int N);

#endif
