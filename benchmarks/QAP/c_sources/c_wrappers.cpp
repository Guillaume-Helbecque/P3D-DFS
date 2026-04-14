#include "../c_headers/c_wrappers.h"

#include "../c_headers/bound_glb.hpp"
#include "../c_headers/bound_rlt1.hpp"

#include <cstring>

extern "C"
longint bound_GLB_wrapper(int* mapping, int* available, int depth, int* F,
  int* D, int n, int N)
{
  // Conversion vers std::vector
  std::vector<int> v_mapping(mapping, mapping + n);
  std::vector<bool> v_available(N,true);
  for (int i = 0; i < N; i++) {
    v_available[i] = (available[i] == 0) ? false : true;
  }
  std::vector<int> v_F(F, F + N * N);
  std::vector<int> v_D(D, D + N * N);

  return bound_GLB(v_mapping, v_available, depth, v_F, v_D, n, N);
}

extern "C"
RLT_WarmData_wrapper* RLT_WarmData_wrapper_new(void)
{
  // calloc -> struct zero-initialized; all inner pointers start NULL.
  return (RLT_WarmData_wrapper*)std::calloc(1, sizeof(RLT_WarmData_wrapper));
}

extern "C"
void RLT_WarmData_wrapper_free(RLT_WarmData_wrapper* w)
{
  if (w == nullptr) return;
  std::free(w->leader);
  std::free(w->costs);
  std::free(w->cubic);
  std::free(w->uf);
  std::free(w->al);
  std::free(w);
}

// Free inner buffers without freeing the struct (used before repopulating).
static void rlt_warm_clear_inner(RLT_WarmData_wrapper* w)
{
  if (w == nullptr) return;
  std::free(w->leader); w->leader = nullptr;
  std::free(w->costs);  w->costs  = nullptr;
  std::free(w->cubic);  w->cubic  = nullptr;
  std::free(w->uf);     w->uf     = nullptr;
  std::free(w->al);     w->al     = nullptr;
  w->m = 0;
  w->uf_size = 0;
  w->parent_bound = 0.0;
}

// extern "C"
// RLT_WarmData_wrapper* allocWarm(const int m, const int n, const int depth)
// {
//   size_t size_leader = (size_t)m * m;
//   size_t size_costs  = (size_t)m * m * m * m;
//   size_t size_cubic  = (size_t)m * m * m * m * m * m;
//   size_t size_al     = (size_t)m;
//   size_t size_uf     = (size_t)n - depth;
//
//   RLT_WarmData_wrapper* out = (RLT_WarmData_wrapper*)malloc(sizeof(RLT_WarmData_wrapper));
//
//   if (out) {
//     out->leader = (double*)malloc(size_leader * sizeof(double));
//     out->costs  = (double*)malloc(size_costs  * sizeof(double));
//     out->cubic  = (double*)malloc(size_cubic  * sizeof(double));
//     out->al     = (int*)malloc(size_al * sizeof(int));
//     out->uf     = (int*)malloc(size_uf * sizeof(int));
//   }
//
//   return out;
// }

extern "C"
longint bound_RLT1_wrapper(const int* mapping, const int* available, int depth, const int* F,
  const int* D, int n, int N, int rlt_itmax, double rlt_tol, longint* best,
  int* opt_solution, const RLT_WarmData_wrapper* warm, int warm_branch_fac,
  int warm_branch_loc, RLT_WarmData_wrapper* out)
{
  // Conversion vers std::vector
  std::vector<int> v_mapping(mapping, mapping + n);
  std::vector<bool> v_available(N, true);
  for (int i = 0; i < N; i++) {
    v_available[i] = (available[i] == 0) ? false : true;
  }
  std::vector<int> v_F(F, F + N * N);
  std::vector<int> v_D(D, D + N * N);

  // `opt_solution` is allowed to be nullptr from the Chapel side; use a local
  // buffer so bound_RLT1 can safely write to it. Results are copied back only
  // if the caller provided a real pointer.
  std::vector<int> v_opt_solution(n, -1);
  if (opt_solution != nullptr) {
    for (int i = 0; i < n; ++i) v_opt_solution[i] = opt_solution[i];
  }

  // Take incoming UB from caller (or INF if nullptr). bound_RLT1 takes UB by reference
  // and may tighten it; propagate the final value back at the end.
  longint local_UB = (best != nullptr) ? *best
                                       : std::numeric_limits<longint>::max();

  longint res = 0;

  if (warm != nullptr && warm->m > 0) {
    // Warm-start path: reconstruct parent's reduced matrices from the C-side buffers.
    RLT_WarmData v_warm;
    const int pm = warm->m;
    const int puf_size = (warm->uf_size > 0) ? warm->uf_size : pm;

    v_warm.m = pm;
    v_warm.parent_bound = warm->parent_bound;

    if (warm->leader != nullptr)
      v_warm.leader.assign(warm->leader, warm->leader + (size_t)pm * pm);
    if (warm->costs != nullptr)
      v_warm.costs.assign(warm->costs, warm->costs + (size_t)pm * pm * pm * pm);
    // cubic is unused by RLT1 but is part of the struct for RLT2 compatibility.
    // Left empty here; RLT1 never reads from warm->cubic.
    if (warm->uf != nullptr)
      v_warm.uf.assign(warm->uf, warm->uf + puf_size);
    if (warm->al != nullptr)
      v_warm.al.assign(warm->al, warm->al + pm);

    res = bound_RLT1(v_mapping, v_available, depth, v_F, v_D, n, N, rlt_itmax,
      rlt_tol, local_UB, v_opt_solution, &v_warm, warm_branch_fac,
      warm_branch_loc, nullptr);
  }
  else if (out != nullptr) {
    // Cold-start path that wants warm data for subsequent children.
    RLT_WarmData v_out;

    res = bound_RLT1(v_mapping, v_available, depth, v_F, v_D, n, N, rlt_itmax,
      rlt_tol, local_UB, v_opt_solution, nullptr, warm_branch_fac,
      warm_branch_loc, &v_out);

    // Drop any previously held buffers before repopulating — allows reuse.
    rlt_warm_clear_inner(out);

    const int m = v_out.m;
    const size_t size_leader = (size_t)m * m;
    const size_t size_costs  = (size_t)m * m * m * m;
    const size_t size_cubic  = v_out.cubic.size(); // RLT1 leaves this empty
    const size_t size_al     = v_out.al.size();
    const size_t size_uf     = v_out.uf.size();

    if (size_leader > 0) {
      out->leader = (double*)std::malloc(size_leader * sizeof(double));
      std::memcpy(out->leader, v_out.leader.data(), size_leader * sizeof(double));
    }
    if (size_costs > 0) {
      out->costs = (double*)std::malloc(size_costs * sizeof(double));
      std::memcpy(out->costs, v_out.costs.data(), size_costs * sizeof(double));
    }
    if (size_cubic > 0) {
      out->cubic = (double*)std::malloc(size_cubic * sizeof(double));
      std::memcpy(out->cubic, v_out.cubic.data(), size_cubic * sizeof(double));
    }
    if (size_al > 0) {
      out->al = (int*)std::malloc(size_al * sizeof(int));
      std::memcpy(out->al, v_out.al.data(), size_al * sizeof(int));
    }
    if (size_uf > 0) {
      out->uf = (int*)std::malloc(size_uf * sizeof(int));
      std::memcpy(out->uf, v_out.uf.data(), size_uf * sizeof(int));
    }

    out->m            = m;
    out->uf_size      = (int)size_uf;
    out->parent_bound = v_out.parent_bound;
  }
  else {
    // No warm, no out: just compute the bound.
    res = bound_RLT1(v_mapping, v_available, depth, v_F, v_D, n, N, rlt_itmax,
      rlt_tol, local_UB, v_opt_solution, nullptr, warm_branch_fac,
      warm_branch_loc, nullptr);
  }

  // Propagate updated UB back to caller.
  if (best != nullptr) *best = local_UB;

  // Copy refined opt_solution back if the caller tracks it.
  if (opt_solution != nullptr) {
    for (int i = 0; i < n; ++i) opt_solution[i] = v_opt_solution[i];
  }

  return res;
}
