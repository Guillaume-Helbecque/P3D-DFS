#ifndef __C_WRAPPERS__
#define __C_WRAPPERS__

#ifdef __cplusplus
extern "C" {
#endif

long long bound_GLB_wrapper(int* mapping, int* available, int depth, int* F,
  int* D, int n, int N);

typedef struct RLT_WarmData_wrapper
{
  double *leader;      // parent's reduced leader (m^2)
  double *costs;       // parent's reduced quadratic costs (m^4)
  double *cubic;       // parent's reduced cubic costs (m^6)
  int *uf;             // parent's unassigned facilities
  int *al;             // parent's available locations
  int m;               // parent's subproblem size
  double parent_bound; // parent's computed bound (fixed_cost + R'), doubled space
} RLT_WarmData_wrapper;

long long bound_RLT1_wrapper(const int* mapping, const int* available, int depth, const int* F,
  const int* D, int n, int N, int rlt_itmax, double rlt_tol, long long* best,
  int* opt_solution, const RLT_WarmData_wrapper* warm, int warm_branch_fac,
  int warm_branch_loc, RLT_WarmData_wrapper* out);

#ifdef __cplusplus
}
#endif

#endif
