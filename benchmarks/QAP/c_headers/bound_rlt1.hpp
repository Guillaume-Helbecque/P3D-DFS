#ifndef __BOUND_RLT1__
#define __BOUND_RLT1__

#include "utils.hpp"

// CPU-based RLT1 lower bound
longint bound_RLT1(const std::vector<int>& mapping,
                   const std::vector<bool>& available,
                   int depth,
                   const std::vector<int>& F,
                   const std::vector<int>& D,
                   int n, int N,
                   int rlt_itmax, double rlt_tol,
                   longint& UB,
                   std::vector<int>& opt_solution,
                   const RLT_WarmData* warm, int warm_branch_fac, int warm_branch_loc,
                   RLT_WarmData* out);

#endif
