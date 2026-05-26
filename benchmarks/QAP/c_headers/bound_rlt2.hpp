#ifndef __BOUND_RLT2__
#define __BOUND_RLT2__

#include "utils.hpp"

// CPU-based RLT2 lower bound
longint bound_RLT2(const std::vector<int>& mapping,
                   const std::vector<bool>& available,
                   int depth,
                   const std::vector<int>& F,
                   const std::vector<int>& D,
                   int n, int N,
                   int rlt2_itmax, double rlt2_tol,
                   longint& UB,
                   std::vector<int>& opt_solution,
                   const RLT_WarmData* warm, int warm_branch_fac, int warm_branch_loc,
                   RLT_WarmData* out);

#endif
