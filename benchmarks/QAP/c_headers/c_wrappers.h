#ifndef __C_WRAPPERS__
#define __C_WRAPPERS__

#ifdef __cplusplus
extern "C" {
#endif

long long bound_GLB_wrapper(int* mapping, int* available, int depth, int* F,
  int* D, int n, int N);

long long bound_IGLB_wrapper(int* mapping, int* available, int depth, int* F,
  int* D, int n, int N);

long long bound_EVB_wrapper(int* mapping, int* available, int depth, int* F,
  int* D, int n, int N, long long ub);

typedef struct RLT_WarmData_wrapper
{
  double *leader;      // parent's reduced leader (m^2)
  double *costs;       // parent's reduced quadratic costs (m^4)
  double *cubic;       // parent's reduced cubic costs (m^6)
  int *uf;             // parent's unassigned facilities
  int *al;             // parent's available locations
  int m;               // parent's subproblem size
  int uf_size;         // number of unassigned facilities (n - parent_depth)
  double parent_bound; // parent's computed bound (fixed_cost + R'), doubled space
} RLT_WarmData_wrapper;

// Allocate a zero-initialized RLT_WarmData_wrapper (all inner pointers NULL, sizes 0).
// Caller owns the returned pointer and must free it via RLT_WarmData_wrapper_free.
RLT_WarmData_wrapper* RLT_WarmData_wrapper_new(void);

// Free all inner buffers and the wrapper struct itself.
void RLT_WarmData_wrapper_free(RLT_WarmData_wrapper* w);

long long bound_RLT1_wrapper(const int* mapping, const int* available, int depth, const int* F,
  const int* D, int n, int N, int rlt_itmax, double rlt_tol, long long* best,
  int* opt_solution, const RLT_WarmData_wrapper* warm, int warm_branch_fac,
  int warm_branch_loc, RLT_WarmData_wrapper* out);

long long bound_RLT2_wrapper(const int* mapping, const int* available, int depth, const int* F,
  const int* D, int n, int N, int rlt_itmax, double rlt_tol, long long* best,
  int* opt_solution, const RLT_WarmData_wrapper* warm, int warm_branch_fac,
  int warm_branch_loc, RLT_WarmData_wrapper* out);

typedef struct QPB_ParentContext QPB_ParentContext;

// Allocate and set up a parent context
QPB_ParentContext* QPB_ParentContext_new(
  const int* parent_mapping, const int* parent_available,
  int parent_depth, int branch_fac_i,
  const int* F, const int* D, int n, int N,
  int qpb_maxFW, double qpb_tol,
  int parent_qpb_has_data, int parent_qpb_m,
  const double* parent_qpb_X,
  const double* parent_qpb_reduced_costs,
  const int* parent_qpb_unassigned_fac,
  const int* parent_qpb_unassigned_loc,
  long long parent_qpb_fixed_cost,
  double parent_qpb_bound_cont_last,
  int f_symmetric, int d_symmetric);

void QPB_ParentContext_free(QPB_ParentContext* ctx);

long long bound_QPB_child(
  QPB_ParentContext* ctx, int branch_loc_j, long long UB,
  double* out_qpb_X, double* out_qpb_reduced_costs,
  int* out_qpb_unassigned_fac, int* out_qpb_unassigned_loc,
  int* out_qpb_m, int* out_qpb_has_data,
  double* out_qpb_bound_cont, double* out_qpb_bound_cont_last,
  long long* out_qpb_fixed_cost);

int is_symmetric_matrix_c(const int* M, int n, int N);

#ifdef __cplusplus
}
#endif

#endif
