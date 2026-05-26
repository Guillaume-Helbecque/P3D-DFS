#include "../c_headers/c_wrappers.h"
#include "../c_headers/bound_qpb.hpp"
#include "../c_headers/bound_evb.hpp"
#include "../c_headers/bound_glb.hpp"
#include "../c_headers/utils.hpp"

#include <Eigen/Dense>
#include <vector>
#include <cmath>
#include <algorithm>
#include <climits>
#include <cstring>


// =============================================================================
// QPB wrapper layer: bridges the Chapel/C boundary for the QPB lower bound.
//
// Per-decompose-call lifetime:
//   1. Chapel builds a QPB_ParentContext via QPB_ParentContext_new(). This
//      precomputes the parent-side data shared by every sibling (parent_C
//      cross-cost cache, A-side eigendecomposition cache, parent's qpb-side
//      indices for the variable-fixing prune lookup, and parent's reduced
//      matrices when parent has QPB data).
//   2. For each candidate location j, Chapel calls bound_QPB_child(). The
//      wrapper does the cheap variable-fixing pre-prune, then the full QPB
//      Frank-Wolfe solve (warm-started from parent.X via Sinkhorn extraction
//      when available), and writes the child's QPB data into the caller-
//      supplied output buffers.
//   3. Chapel calls QPB_ParentContext_free() once the for-loop completes.
//
// Lifetime + threading split for the various caches:
//   * Parent-shared state (parent_C, A-side QPBEigenCache, parent's
//     reduced-cost / X matrices, the location-to-index maps, parent_uf /
//     parent_ul / parent_assigned): VALUE MEMBERS of QPB_ParentContext.
//     Built once per parent in QPB_ParentContext_new, reused across the
//     sibling loop, freed in QPB_ParentContext_free.
//   * Per-call scratch (child_uf / child_al lists, A_sub / B_sub / C_sub
//     Eigen matrices, warmX_buf): file-static `thread_local` inside
//     bound_QPB_child. Reused across siblings + decompose calls on the
//     same OS thread (Eigen's .resize() is a no-op when the shape already
//     matches, so siblings of one parent never reallocate).
//   * QPB solver: file-static `thread_local` (g_qpb_solver). Its
//     persistent FW / LAP scratch grows lazily on the first solve() and
//     stays alive across every decompose call on the thread, matching the
//     C++ project's one-solver-per-MPI-rank lifetime.
//
// Chapel task migration safety:
//   Chapel tasks may migrate between OS threads at yield points (bag push,
//   sync-variable writes between bound_QPB_child calls). thread_local data
//   on the new thread may differ from the old thread's, but each call
//   re-populates everything it reads -- the lazy-grow in Eigen / std::vector
//   transparently handles the size mismatch. Within a single bound_QPB_child
//   call there are NO yield points (pure C++ + Eigen), so the task cannot
//   migrate mid-call: every read of a thread_local sees the value the
//   matching write produced earlier in the same call.
// =============================================================================


// =============================================================================
//  Helpers (file-static)
// =============================================================================

// Compute QAP objective from raw pointers; avoids the std::vector copy that
// would otherwise be paid for every Objective() call inside the per-child
// hot path.
static inline longint compute_objective_raw(const int* mapping, const int* F,
                                            const int* D, int n, int N)
{
    longint cost = 0;
    for (int i = 0; i < n; ++i) {
        if (mapping[i] == -1) continue;
        const int mi = mapping[i];
        for (int j = 0; j < n; ++j) {
            if (mapping[j] == -1) continue;
            cost += (longint)F[i * N + j] * (longint)D[mi * N + mapping[j]];
        }
    }
    return cost;
}

// Incremental fixed-cost update: child_fixed = parent_fixed + (terms
// introduced by assigning facility i to location j). O(parent_depth) work
// vs O(parent_depth^2) for a full Objective() recompute. The two
// directional terms (F[i,a] * D[j,b] and F[a,i] * D[b,j]) plus the self-
// loop F[i,i] * D[j,j] together cover every (i, x) and (x, i) pair that
// the new assignment introduces.
static inline longint incremental_fixed_cost(longint parent_fixed_cost,
                                              const int* parent_mapping,
                                              const int* F, const int* D,
                                              int n, int N, int i, int j)
{
    longint incr = (longint)F[i * N + i] * (longint)D[j * N + j];
    for (int a = 0; a < n; ++a) {
        if (parent_mapping[a] == -1 || a == i) continue;
        const int b = parent_mapping[a];
        incr += (longint)F[i * N + a] * (longint)D[j * N + b];
        incr += (longint)F[a * N + i] * (longint)D[b * N + j];
    }
    return parent_fixed_cost + incr;
}


// =============================================================================
//  QPB_ParentContext: state shared across siblings of one parent
// =============================================================================

struct QPB_ParentContext {
    // ---- Input data (borrowed pointers, valid for the lifetime of the ctx
    //      because the Chapel parent node + Problem stay alive throughout
    //      the enclosing decompose_QPB call). ----
    const int* F;
    const int* D;
    const int* parent_mapping;
    const int* parent_available;
    int n;
    int N;
    int parent_depth;
    int branch_fac_i;
    bool f_symmetric;
    bool d_symmetric;
    QPBParams params;

    // ---- Parent's fixed cost, precomputed once so each sibling's
    //      child_fixed_cost is O(parent_depth) incremental. ----
    longint parent_fixed_cost;

    // ---- Parent QPB data (only meaningful when has_parent_data). ----
    //      parent_qpb_X_ptr / parent_qpb_reduced_costs_ptr are borrowed
    //      directly from the parent Chapel record's c_array storage; both
    //      remain valid for the lifetime of the context because the
    //      enclosing decompose_QPB call keeps the parent node alive.
    //
    //      reduced_costs stays a raw pointer end-to-end: variable fixing
    //      reads exactly ONE element per sibling, so building a pm x pm
    //      Eigen matrix in setup was pure waste (pm^2 doubles + a heap
    //      allocation per decompose).
    //
    //      parent_X is consumed by extractWarmStart, which takes a
    //      const Eigen::MatrixXd&; we therefore still need an Eigen
    //      matrix, but build it LAZILY on first warm-start use rather
    //      than eagerly in setup. Parents whose siblings all get pruned
    //      by variable fixing (or whose mc <= 2 so warm-start is
    //      bypassed) skip the build entirely.
    bool has_parent_data;
    int pm;                                // parent's subproblem size (= len of parent_qpb_uf)
    const double* parent_qpb_X_ptr;        // borrowed pointer, pm x pm column-major (lazy parent_X source)
    const double* parent_qpb_reduced_costs_ptr;  // borrowed pointer, pm x pm column-major
    Eigen::MatrixXd parent_X;              // lazy-built from parent_qpb_X_ptr on first warm-start use
    bool parent_X_built;                   // true once parent_X has been populated for this decompose
    std::vector<int> parent_qpb_uf;        // parent's unassigned-fac list (stored)
    std::vector<int> parent_qpb_ul;        // parent's unassigned-loc list (stored)
    longint parent_qpb_fixed_cost;
    double parent_qpb_bound_cont_last;
    int i_idx_in_parent_qpb_uf;            // branch_fac_i's index in parent_qpb_uf (-1 if absent)
    std::vector<int> qpb_loc_to_idx;       // map: global loc -> index in parent_qpb_ul (-1 = absent)

    // ---- Parent-side caches recomputed from current mapping/available
    //      (same content as parent.qpbUnassignedFac/Loc when has_parent_data
    //      holds, but we always compute them because parent_C also needs the
    //      assigned-fac list). ----
    std::vector<int> parent_uf;            // facilities still unassigned at parent
    std::vector<int> parent_ul;            // locations still available at parent
    std::vector<int> parent_assigned;      // already-assigned facilities
    int parent_m;                          // = parent_uf.size()
    int parent_p;                          // = parent_ul.size()
    int parent_i_branch_idx;               // branch_fac_i's index in parent_uf
    std::vector<int> parent_loc_to_idx;    // map: global loc -> index in parent_ul

    // ---- parent_C: m_p x p_p cross-cost matrix from parent's already-
    //      assigned facs. Each sibling builds its own C_sub by reading
    //      from this cache and adding only the new (i, j) term, instead of
    //      re-summing the O(parent_depth) cross terms from scratch. ----
    Eigen::MatrixXd parent_C;

    // ---- child_uf: the list parent_uf minus branch_fac_i, in parent_uf's
    //      order. SAME for every sibling of one parent (siblings differ only
    //      in the branching location). Cached so bound_QPB_child doesn't
    //      rebuild it from parent_mapping on every call. ----
    std::vector<int> child_uf;
    int mc;                                // = child_uf.size() = parent_m - 1

    // ---- A_sub: the m_c x m_c flow submatrix over child_uf, already
    //      symmetrized when !f_symmetric. SAME for every sibling (siblings
    //      share the same set of unassigned facilities). Cached so
    //      bound_QPB_child can skip the per-sibling F-reads + symmetrize
    //      .eval(). Also fed directly to buildEigenCacheA in setup, so the
    //      former local A_child temporary is gone. ----
    Eigen::MatrixXd A_sub;

    // ---- A-side eigendecomposition cache for the child subproblem (size
    //      mc = parent_m - 1). Built once per parent because every sibling
    //      shares the same A submatrix (siblings branch on the same
    //      facility, only the location differs). The cache stays empty
    //      (cache_A.n = 0) for mc <= 2; the QPBSolver's n <= 2 fast paths
    //      don't consume it. ----
    QPBEigenCache cache_A;

    // (No QPBSolver member here -- see g_qpb_solver below: solver is
    //  thread_local so its persistent FW / LAP scratch is reused across
    //  every decompose call on the same thread, matching the C++ project's
    //  one-solver-per-MPI-rank lifetime.)
};

// ---- Thread-local QPBSolver. Persistent scratch (lap_u, lap_v, solve_X,
//      solve_G, solve_AXB, ...) grows lazily on the first solve() call and
//      is reused for every subsequent call on this thread. In the C++
//      project this maps one-to-one to "one QPBSolver per MPI rank" (the
//      driver creates a single solver and passes it down). For Chapel,
//      thread_local is the corresponding semantics: workers share a
//      thread, the solver scratch persists across decompose calls on the
//      thread. Chapel tasks may migrate between threads at yield points
//      (e.g., bag push, sync writes between bound_QPB_child calls), in
//      which case the new thread's solver might be smaller / fresh; the
//      lazy-grow keeps that case correct (one extra realloc on first
//      solve()) at the cost of momentarily losing scratch reuse. Within
//      a single bound_QPB_child call there are no yield points, so the
//      task can't migrate mid-call -- the solver state used at each step
//      is consistent.
static thread_local QPBSolver g_qpb_solver;


// =============================================================================
//  is_symmetric_matrix_c: extern "C" entry point for the Chapel symmetry probe
// =============================================================================

extern "C"
int is_symmetric_matrix_c(const int* M, int n, int N)
{
    for (int i = 0; i < n; ++i)
        for (int j = i + 1; j < n; ++j)
            if (M[i * N + j] != M[j * N + i]) return 0;
    return 1;
}


// =============================================================================
//  QPB_ParentContext_new: parent-side setup, called once per decompose_QPB
// =============================================================================

extern "C"
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
    int f_symmetric, int d_symmetric)
{
    auto ctx = new QPB_ParentContext();

    ctx->F             = F;
    ctx->D             = D;
    ctx->parent_mapping = parent_mapping;
    ctx->parent_available = parent_available;
    ctx->n             = n;
    ctx->N             = N;
    ctx->parent_depth  = parent_depth;
    ctx->branch_fac_i  = branch_fac_i;
    ctx->params.maxFW  = qpb_maxFW;
    ctx->params.tol    = qpb_tol;
    ctx->f_symmetric   = (f_symmetric != 0);
    ctx->d_symmetric   = (d_symmetric != 0);

    // ---- Parent's fixed cost. When parent_qpb_has_data is set the value is
    //      already on the parent (the wrapper wrote it the last time this
    //      node was a child), so we reuse it instead of paying for another
    //      O(parent_depth^2) Objective recompute. The fall-through path
    //      (root, or a parent that previously fell through to GLB on a
    //      rectangular subproblem) still computes fresh from raw F / D. ----
    if (parent_qpb_has_data != 0) {
        ctx->parent_fixed_cost = (longint)parent_qpb_fixed_cost;
    } else {
        ctx->parent_fixed_cost = compute_objective_raw(parent_mapping, F, D, n, N);
    }

    // ---- Build parent_uf / parent_ul / parent_assigned from the current
    //      mapping / available. Iteration order is 0..n / 0..N, which
    //      matches the order used by the parent's qpbUnassignedFac /
    //      qpbUnassignedLoc fields at the time they were stored (the
    //      previous decompose call's child construction also iterated
    //      0..n / 0..N on map/av). So parent_uf == parent_qpb_uf and
    //      parent_ul == parent_qpb_ul whenever has_parent_data holds. ----
    ctx->parent_uf.reserve((size_t)(n - parent_depth));
    ctx->parent_assigned.reserve((size_t)parent_depth);
    for (int f = 0; f < n; ++f) {
        if (parent_mapping[f] == -1) ctx->parent_uf.push_back(f);
        else                          ctx->parent_assigned.push_back(f);
    }
    ctx->parent_ul.reserve((size_t)(N - parent_depth));
    for (int l = 0; l < N; ++l)
        if (parent_available[l] != 0) ctx->parent_ul.push_back(l);

    ctx->parent_m = (int)ctx->parent_uf.size();
    ctx->parent_p = (int)ctx->parent_ul.size();

    // ---- Locate branch_fac_i in parent_uf. ----
    ctx->parent_i_branch_idx = -1;
    for (int idx = 0; idx < ctx->parent_m; ++idx) {
        if (ctx->parent_uf[idx] == branch_fac_i) {
            ctx->parent_i_branch_idx = idx;
            break;
        }
    }

    // ---- Build parent_loc_to_idx. ----
    ctx->parent_loc_to_idx.assign((size_t)N, -1);
    for (int idx = 0; idx < ctx->parent_p; ++idx)
        ctx->parent_loc_to_idx[ctx->parent_ul[idx]] = idx;

    // ---- parent_C cache. Element (ii, kk) is the cross cost between the
    //      ii-th unassigned facility and the kk-th unassigned location,
    //      summing only over the parent's already-assigned facilities.
    //      Each sibling later adds the (i, j) term to derive its own
    //      C_sub via the index-shift mapping documented below. ----
    ctx->parent_C.resize(ctx->parent_m, ctx->parent_p);
    for (int ii = 0; ii < ctx->parent_m; ++ii) {
        const int fi = ctx->parent_uf[ii];
        for (int kk = 0; kk < ctx->parent_p; ++kk) {
            const int lk = ctx->parent_ul[kk];
            double cross = 0.0;
            for (int a : ctx->parent_assigned) {
                cross += (double)F[fi * N + a] * (double)D[lk * N + parent_mapping[a]];
                cross += (double)F[a * N + fi] * (double)D[parent_mapping[a] * N + lk];
            }
            ctx->parent_C(ii, kk) = cross;
        }
    }

    // ---- Parent's QPB data (variable-fixing + warm-start). ----
    ctx->has_parent_data = (parent_qpb_has_data != 0 && parent_qpb_m > 0);

    if (ctx->has_parent_data) {
        ctx->pm = parent_qpb_m;
        ctx->parent_qpb_uf.assign(parent_qpb_unassigned_fac,
                                  parent_qpb_unassigned_fac + parent_qpb_m);
        ctx->parent_qpb_ul.assign(parent_qpb_unassigned_loc,
                                  parent_qpb_unassigned_loc + parent_qpb_m);
        ctx->parent_qpb_fixed_cost      = (longint)parent_qpb_fixed_cost;
        ctx->parent_qpb_bound_cont_last = parent_qpb_bound_cont_last;

        // Just borrow the pointers; no per-decompose Eigen matmul or copy.
        // parent_X will be materialized lazily in bound_QPB_child when (and
        // if) extractWarmStart actually needs it; reduced_costs is consumed
        // one-element-at-a-time by variable fixing, so it never needs an
        // Eigen matrix at all.
        ctx->parent_qpb_X_ptr             = parent_qpb_X;
        ctx->parent_qpb_reduced_costs_ptr = parent_qpb_reduced_costs;
        ctx->parent_X_built               = false;

        ctx->i_idx_in_parent_qpb_uf = -1;
        for (int idx = 0; idx < parent_qpb_m; ++idx) {
            if (ctx->parent_qpb_uf[idx] == branch_fac_i) {
                ctx->i_idx_in_parent_qpb_uf = idx;
                break;
            }
        }
        ctx->qpb_loc_to_idx.assign((size_t)N, -1);
        for (int idx = 0; idx < parent_qpb_m; ++idx)
            ctx->qpb_loc_to_idx[ctx->parent_qpb_ul[idx]] = idx;
    } else {
        ctx->pm = 0;
        ctx->parent_qpb_X_ptr             = nullptr;
        ctx->parent_qpb_reduced_costs_ptr = nullptr;
        ctx->parent_X_built               = false;
        ctx->i_idx_in_parent_qpb_uf = -1;
    }

    // ---- Cache child_uf and A_sub once. Both are identical across every
    //      sibling of this parent (siblings differ only in the branching
    //      location j). Caching here lets bound_QPB_child skip
    //        * O(n) construction of child_uf
    //        * O(mc^2) F-reads + an O(mc^2) Eigen .eval() symmetrize
    //      per sibling. A_sub also replaces the former local A_child
    //      temporary that fed buildEigenCacheA, so the two paths converge
    //      to a single cached matrix. ----
    ctx->mc = ctx->parent_m - 1;
    ctx->child_uf.clear();
    if (ctx->mc > 0 && ctx->parent_i_branch_idx >= 0) {
        ctx->child_uf.reserve((size_t)ctx->mc);
        for (int idx = 0; idx < ctx->parent_m; ++idx) {
            if (idx == ctx->parent_i_branch_idx) continue;
            ctx->child_uf.push_back(ctx->parent_uf[idx]);
        }

        ctx->A_sub.resize(ctx->mc, ctx->mc);
        for (int ii = 0; ii < ctx->mc; ++ii)
            for (int jj = 0; jj < ctx->mc; ++jj)
                ctx->A_sub(ii, jj) =
                    (double)F[ctx->child_uf[ii] * N + ctx->child_uf[jj]];
        // Symmetrize iff F isn't already integer-symmetric (matches the
        // C++ Node::decompose's A_child symmetrize step).
        if (!ctx->f_symmetric)
            ctx->A_sub = (0.5 * (ctx->A_sub + ctx->A_sub.transpose())).eval();
    }

    // ---- A-side eigendecomposition cache for the child subproblem.
    //      Skipped when mc <= 2 (QPBSolver's n <= 2 fast paths don't read
    //      the cache). buildEigenCacheA consumes A_sub directly -- the
    //      former A_child local matrix is gone. ----
    if (ctx->mc > 2 && ctx->parent_i_branch_idx >= 0) {
        QPBSolver::buildEigenCacheA(ctx->A_sub, ctx->mc, ctx->cache_A);
    } else {
        ctx->cache_A.n = 0;
    }

    return ctx;
}


extern "C"
void QPB_ParentContext_free(QPB_ParentContext* ctx)
{
    if (ctx == nullptr) return;
    delete ctx;
}


// =============================================================================
//  bound_QPB_child: per-sibling bound + warm-start data emission
// =============================================================================

extern "C"
long long bound_QPB_child(
    QPB_ParentContext* ctx, int branch_loc_j, long long UB,
    double* out_qpb_X, double* out_qpb_reduced_costs,
    int* out_qpb_unassigned_fac, int* out_qpb_unassigned_loc,
    int* out_qpb_m, int* out_qpb_has_data,
    double* out_qpb_bound_cont, double* out_qpb_bound_cont_last,
    long long* out_qpb_fixed_cost)
{
    *out_qpb_has_data = 0;
    *out_qpb_m        = 0;
    *out_qpb_bound_cont      = 0.0;
    *out_qpb_bound_cont_last = 0.0;

    const int n = ctx->n;
    const int N = ctx->N;
    const int i = ctx->branch_fac_i;
    const int j = branch_loc_j;

    // ---- Variable fixing pre-prune. Uses parent's reduced cost matrix +
    //      the cheap roundoff envelope. Returns LLONG_MAX so the caller
    //      knows to skip without even pushing the child.
    //
    //      The reduced-cost lookup reads ONE element directly from the
    //      parent's flat column-major buffer -- no Eigen matrix is built
    //      at all on this side. flat[col * pm + row] == M(row, col). ----
    if (ctx->has_parent_data && ctx->i_idx_in_parent_qpb_uf >= 0) {
        const int j_idx = ctx->qpb_loc_to_idx[j];
        if (j_idx >= 0) {
            const double rc = ctx->parent_qpb_reduced_costs_ptr[
                (size_t)j_idx * ctx->pm + ctx->i_idx_in_parent_qpb_uf];
            const double est = (double)ctx->parent_qpb_fixed_cost
                             + ctx->parent_qpb_bound_cont_last
                             + rc;
            const double vf_tol =
                std::max(QPB_VF_TOL_BASE, QPB_VF_TOL_REL * std::abs(est));
            if (static_cast<longint>(std::ceil(est - vf_tol)) >= (longint)UB) {
                return LLONG_MAX;  // pruned
            }
        }
    }

    // ---- child_uf: cached on the context (built once per parent in
    //      QPB_ParentContext_new since it's identical across siblings).
    //      child_al: still per-sibling (its exclusion of j varies),
    //      thread_local + clear() so the vector storage is reused across
    //      siblings + decompose calls. Safe under Chapel's task model
    //      because bound_QPB_child has no runtime yield points, so the
    //      task cannot migrate threads between the .clear() and the
    //      .push_back()s. ----
    const std::vector<int>& child_uf = ctx->child_uf;
    const int mc = ctx->mc;

    static thread_local std::vector<int> child_al;
    child_al.clear();
    child_al.reserve((size_t)(ctx->parent_p - 1));
    for (int l = 0; l < N; ++l) {
        if (l == j) continue;
        if (ctx->parent_available[l] != 0) child_al.push_back(l);
    }
    const int pc = (int)child_al.size();

    // ---- Incremental fixed cost: parent_fixed_cost + new (i, j) terms. ----
    const longint child_fixed_cost = incremental_fixed_cost(
        ctx->parent_fixed_cost, ctx->parent_mapping,
        ctx->F, ctx->D, n, N, i, j);
    *out_qpb_fixed_cost = (long long)child_fixed_cost;

    if (mc == 0) {
        // Defensive: leaves should never reach this path. Return the leaf
        // cost so the caller still sees a well-defined value if it ever does.
        return (long long)child_fixed_cost;
    }

    // ---- Rectangular subproblem fallback: GLB on the child's reduced
    //      problem. No QPB warm-start data is emitted. ----
    if (mc != pc) {
        // bound_GLB takes std::vector arguments. The vectors are local to
        // this branch, so the conversion overhead is contained to the
        // (rare) rectangular case.
        std::vector<int> v_mapping((size_t)n);
        for (int k = 0; k < n; ++k) v_mapping[k] = ctx->parent_mapping[k];
        v_mapping[i] = j;
        std::vector<bool> v_available((size_t)N, false);
        for (int l : child_al) v_available[l] = true;
        std::vector<int> v_F(ctx->F, ctx->F + (size_t)N * N);
        std::vector<int> v_D(ctx->D, ctx->D + (size_t)N * N);
        return (long long)bound_GLB(v_mapping, v_available,
                                    ctx->parent_depth + 1, v_F, v_D, n, N);
    }

    // ===========================================================================
    //  Square subproblem: full QPB Frank-Wolfe with warm-start
    // ===========================================================================

    // ---- A_sub: cached on the context (already symmetrized in setup when
    //      !f_symmetric). Reading via const ref keeps siblings sharing the
    //      single matrix and avoids the per-sibling F-reads + .eval()
    //      symmetrize that the previous version paid for.
    //      B_sub / C_sub: still per-sibling (B_sub depends on child_al,
    //      C_sub on j). thread_local so Eigen's resize() is a no-op when
    //      mc matches across siblings. ----
    const Eigen::MatrixXd& A_sub = ctx->A_sub;

    static thread_local Eigen::MatrixXd B_sub, C_sub;
    B_sub.resize(mc, mc);
    C_sub.resize(mc, mc);
    for (int ii = 0; ii < mc; ++ii)
        for (int jj = 0; jj < mc; ++jj)
            B_sub(ii, jj) = (double)ctx->D[child_al[ii] * N + child_al[jj]];

    // ---- C_sub: from parent_C cache + the (i, j) branching term.
    //      Index remap from child to parent indices:
    //        parent_idx = child_idx + (child_idx >= branch_idx ? 1 : 0)
    //      -- skip past the removed (= branching) entry in parent's UF / UL.
    //      The new term covers cross-costs against the newly-assigned (i, j),
    //      which parent_C does not include. ----
    const int parent_k_branch_idx = ctx->parent_loc_to_idx[j];
    for (int ii = 0; ii < mc; ++ii) {
        const int pi = ii + (ii >= ctx->parent_i_branch_idx ? 1 : 0);
        const int fi = child_uf[ii];
        for (int kk = 0; kk < mc; ++kk) {
            const int pk = kk + (kk >= parent_k_branch_idx ? 1 : 0);
            const int lk = child_al[kk];
            const double base = ctx->parent_C(pi, pk);
            const double new_term =
                  (double)ctx->F[fi * N + i] * (double)ctx->D[lk * N + j]
                + (double)ctx->F[i  * N + fi] * (double)ctx->D[j  * N + lk];
            C_sub(ii, kk) = base + new_term;
        }
    }

    // ---- Asymmetry correction. Three cases:
    //        * mc > 2: cached overload (A-side data shared across siblings).
    //        * mc <= 2 and f_symmetric: ctx->A_sub == original A_sub, so
    //          pass it directly -- fnormFa is correctly 0.
    //        * mc <= 2 and !f_symmetric: ctx->A_sub was symmetrized in
    //          setup, so reading it would give fnormFa = 0 (wrong).
    //          Reconstruct the original 1-2-element A_sub from F for the
    //          correction. Cheap (mc^2 <= 4 reads). ----
    double asym_correction;
    if (ctx->cache_A.n > 0) {
        asym_correction =
            compute_asym_correction(ctx->cache_A.fnormFa, ctx->cache_A.singFa,
                                    B_sub, mc);
    } else if (ctx->f_symmetric) {
        asym_correction = compute_asym_correction(A_sub, B_sub, mc, mc);
    } else {
        Eigen::MatrixXd A_sub_orig(mc, mc);
        for (int ii = 0; ii < mc; ++ii)
            for (int jj = 0; jj < mc; ++jj)
                A_sub_orig(ii, jj) =
                    (double)ctx->F[child_uf[ii] * N + child_uf[jj]];
        asym_correction = compute_asym_correction(A_sub_orig, B_sub, mc, mc);
    }

    // ---- Symmetrize B_sub iff D wasn't already integer-symmetric.
    //      (A_sub was symmetrized at context-setup time, so nothing to do
    //      for it here.) ----
    if (!ctx->d_symmetric)
        B_sub = (0.5 * (B_sub + B_sub.transpose())).eval();

    // ---- Warm-start X from parent's X (Sinkhorn-projected). The guard
    //      uses ctx->pm > 2 (the parent's stored subproblem size) rather
    //      than parent_X.rows() because parent_X is built LAZILY: it
    //      starts empty and only gets materialized when (and if) the
    //      first warm-start candidate of this decompose passes all the
    //      gates below. Parents that variable-fix-out all their children
    //      (or only have pm <= 2 children) skip the pm x pm matrix copy
    //      entirely. extractWarmStart still requires a const MatrixXd&
    //      argument, so once the gates pass we build it once and reuse.
    //      thread_local warmX_buf is the per-sibling Sinkhorn output. ----
    static thread_local Eigen::MatrixXd warmX_buf;
    const Eigen::MatrixXd* warmPtr = nullptr;
    if (ctx->has_parent_data && ctx->i_idx_in_parent_qpb_uf >= 0
        && ctx->pm > 2)
    {
        const int j_idx = ctx->qpb_loc_to_idx[j];
        if (j_idx >= 0) {
            if (!ctx->parent_X_built) {
                ctx->parent_X.resize(ctx->pm, ctx->pm);
                for (int jj = 0; jj < ctx->pm; ++jj)
                    for (int ii = 0; ii < ctx->pm; ++ii)
                        ctx->parent_X(ii, jj) =
                            ctx->parent_qpb_X_ptr[(size_t)jj * ctx->pm + ii];
                ctx->parent_X_built = true;
            }
            QPBSolver::extractWarmStart(ctx->parent_X,
                                        ctx->i_idx_in_parent_qpb_uf, j_idx,
                                        warmX_buf);
            warmPtr = &warmX_buf;
        }
    }

    // ---- Solve QPB. Passes UB - child_fixed_cost as the early-termination
    //      target so the FW loop can break once the continuous bound
    //      already proves the child won't improve UB. ----
    QPBResult res = g_qpb_solver.solve(
        A_sub, B_sub, C_sub, mc, ctx->params,
        (double)((longint)UB - child_fixed_cost),
        warmPtr,
        ctx->cache_A.n > 0 ? &ctx->cache_A : nullptr);

    // ---- Integer floor with roundoff envelope. ----
    const double corrected   = res.bound + asym_correction;
    const double lb_tol      = std::max(QPB_VF_TOL_BASE,
                                        QPB_VF_TOL_REL * std::abs(corrected));
    const longint remaining  = static_cast<longint>(std::ceil(corrected - lb_tol));
    const longint lb_child   = child_fixed_cost + remaining;

    // ---- Emit child's QPB data only when the child is going to be kept.
    //      Saves the X / dualU copies when the bound already exceeds UB
    //      (caller drops the child anyway). ----
    if (lb_child < (longint)UB) {
        *out_qpb_has_data        = 1;
        *out_qpb_m               = mc;
        *out_qpb_bound_cont      = res.bound + asym_correction;
        *out_qpb_bound_cont_last = res.boundLastIter + asym_correction;

        // X (column-major): out_qpb_X[col * mc + row] = X(row, col).
        for (int jj = 0; jj < mc; ++jj)
            for (int ii = 0; ii < mc; ++ii)
                out_qpb_X[(size_t)jj * mc + ii] = res.X(ii, jj);

        // Reduced costs (column-major): same convention.
        for (int jj = 0; jj < mc; ++jj)
            for (int ii = 0; ii < mc; ++ii)
                out_qpb_reduced_costs[(size_t)jj * mc + ii] = res.dualU(ii, jj);

        for (int ii = 0; ii < mc; ++ii) out_qpb_unassigned_fac[ii] = child_uf[ii];
        for (int ii = 0; ii < mc; ++ii) out_qpb_unassigned_loc[ii] = child_al[ii];
    }

    return (long long)lb_child;
}
