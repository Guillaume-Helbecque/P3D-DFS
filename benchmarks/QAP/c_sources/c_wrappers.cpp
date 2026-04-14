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
longint bound_RLT1_wrapper(const int* mapping, const int* available, int depth, const int* F,
  const int* D, int n, int N, int rlt_itmax, double rlt_tol, longint* best,
  int* opt_solution, const RLT_WarmData_wrapper* warm, int warm_branch_fac,
  int warm_branch_loc, RLT_WarmData_wrapper* out)
{
  // Conversion vers std::vector
  std::vector<int> v_mapping(mapping, mapping + n);
  std::vector<bool> v_available(N,true);
  for (int i = 0; i < N; i++) {
    v_available[i] = (available[i] == 0) ? false : true;
  }
  std::vector<int> v_F(F, F + N * N);
  std::vector<int> v_D(D, D + N * N);
  std::vector<int> v_opt_solution(opt_solution, opt_solution + n);

  longint res = 0;
  longint best = 0;

  if (warm != nullptr) {
    RLT_WarmData v_warm;

    int v_m = warm->m;
    std::vector<double> v_leader(warm->leader, warm->leader + v_m*v_m);
    std::vector<double> v_costs(warm->costs, warm->costs + v_m*v_m*v_m*v_m);
    std::vector<double> v_cubic(warm->cubic, warm->cubic + v_m*v_m*v_m*v_m*v_m*v_m);
    std::vector<int> v_uf(warm->uf, warm->uf + n - depth);
    std::vector<int> v_al(warm->al, warm->al + v_m);
    v_warm.leader = v_leader;
    v_warm.costs = v_costs;
    v_warm.cubic = v_cubic;
    v_warm.uf = v_uf;
    v_warm.al = v_al;
    v_warm.m = v_m;
    v_warm.parent_bound = warm->parent_bound;

    res = bound_RLT1(v_mapping, v_available, depth, v_F, v_D, n, N, rlt_itmax,
      rlt_tol, best, v_opt_solution, &v_warm, warm_branch_fac, warm_branch_loc, nullptr);
  }
  else {
    RLT_WarmData v_out;

    res = bound_RLT1(v_mapping, v_available, depth, v_F, v_D, n, N, rlt_itmax,
      rlt_tol, best, v_opt_solution, nullptr, warm_branch_fac, warm_branch_loc, &v_out);

    int m = v_out.m;

    size_t size_leader = (size_t)m * m;
    size_t size_costs  = (size_t)m * m * m * m;
    size_t size_cubic  = (size_t)m * m * m * m * m * m;
    size_t size_al     = (size_t)m;
    size_t size_uf     = v_out.uf.size();

    out->leader = (double*)malloc(size_leader * sizeof(double));
    out->costs  = (double*)malloc(size_costs  * sizeof(double));
    out->cubic  = (double*)malloc(size_cubic  * sizeof(double));
    out->al     = (int*)malloc(size_al * sizeof(int));
    out->uf     = (int*)malloc(size_uf * sizeof(int));

    memcpy(out->leader, v_out.leader.data(), size_leader * sizeof(double));
    memcpy(out->costs,  v_out.costs.data(),  size_costs  * sizeof(double));
    memcpy(out->cubic,  v_out.cubic.data(),  size_cubic  * sizeof(double));
    memcpy(out->al,     v_out.al.data(),     size_al     * sizeof(int));
    memcpy(out->uf,     v_out.uf.data(),     size_uf     * sizeof(int));

    out->m = m;
    out->parent_bound = v_out.parent_bound;
  }

  return res;
}
