#include "../c_headers/bound_qpb.hpp"
#include "../c_headers/bound_evb.hpp"
#include "../c_headers/bound_glb.hpp"
#include "../c_headers/objective.hpp"
#include <cmath>
#include <algorithm>
#include <numeric>


// ================================================================
//  Bidirectional LAP dual repair (warm-start feasibility helper)
// ================================================================
//
//  After a cost-matrix change, the persisted duals u, v from a previous
//  solveLAPDouble call on a different cost matrix no longer satisfy the
//  SAP feasibility invariant u[i] + v[j] <= cost(i, j). Repaired in two
//  O(n^2) phases:
//
//    Phase 1 -- row trim.  For each row i, compute
//                  viol_i = max(0, max_j(u[i]+v[j] - c[i,j]))
//               and set u[i] := u[i] - viol_i. Afterwards every row with a
//               positive violation is *tight* at the argmax j: u[i]+v[j]
//               equals c[i,j] at that one column, with slack at all others.
//
//    Phase 2 -- column tighten.  For each column j, set
//                  v[j] := min_i(c[i,j] - u[i])
//               i.e. raise v[j] to its largest value that keeps u+v<=c.
//               After Phase 1 the constraint v[j] <= c[i,j]-u[i] holds for
//               every i, so the current v[j] is bounded above by the min,
//               meaning Phase 2 can only INCREASE v[j]. Each column gains
//               a tight (i*, j) pair at the argmin i*, in addition to the
//               row-tight pairs from Phase 1 (which Phase 2 preserves --
//               at a row-tight column the min is achieved at that row, so
//               v stays put). After both phases every row AND every column
//               has at least one tight cell.
//
//  The bidirectional repair gives the subsequent SAP a starting set of
//  duals strictly closer to the LAP optimum than row-only repair: tight
//  cells in BOTH directions means fewer Dijkstra exploration steps per
//  augmentation. The second O(n^2) sweep pays for itself when LAP is a
//  meaningful slice of FW iteration cost (the typical regime here).
// ================================================================

void QPBSolver::repairLAPDuals(const Eigen::MatrixXd& cost, int n)
{
    // Phase 1: row trim.
    for (int i = 1; i <= n; ++i) {
        double ui   = lap_u[i];
        double viol = 0.0;
        for (int j = 1; j <= n; ++j) {
            double cand = ui + lap_v[j] - cost(i - 1, j - 1);
            if (cand > viol) viol = cand;
        }
        lap_u[i] = ui - viol;
    }

    // Phase 2: column tighten. v[j] := min_i(c[i,j] - u[i]).
    for (int j = 1; j <= n; ++j) {
        double max_v = cost(0, j - 1) - lap_u[1];
        for (int i = 2; i <= n; ++i) {
            double slack = cost(i - 1, j - 1) - lap_u[i];
            if (slack < max_v) max_v = slack;
        }
        lap_v[j] = max_v;
    }
}


// ================================================================
//  Floating-point LAP solver (O(n^3) shortest augmenting paths)
// ================================================================
//
//  Persistent scratch buffers (lap_u, lap_v, lap_p, lap_way, lap_minv,
//  lap_used) are class members, grown lazily on first use. Keeping them
//  alive across calls avoids one heap allocation per LAP row, which adds
//  up to tens of millions of tiny mallocs across a full B&B run.
//
//  `warm_start` reuses the row/column duals u, v from the previous call.
//  Caller is responsible for restoring feasibility against the new cost
//  matrix first (call repairLAPDuals). p[] and way[] are always reset
//  because the matching is rebuilt fresh by the SAP regardless.
// ================================================================

double QPBSolver::solveLAPDouble(const Eigen::MatrixXd& cost, int n,
                                  std::vector<int>& assignment,
                                  Eigen::VectorXd& rowDual,
                                  Eigen::VectorXd& colDual,
                                  bool warm_start)
{
    if (n == 0) {
        assignment.clear();
        rowDual.resize(0);
        colDual.resize(0);
        return 0.0;
    }
    if (n == 1) {
        assignment = {0};
        rowDual.resize(1); rowDual(0) = cost(0, 0);
        colDual.resize(1); colDual(0) = 0.0;
        // Keep 1-based duals consistent so a subsequent warm-start sees
        // valid values rather than whatever was last left in lap_u / lap_v.
        if ((int)lap_u.size() < 2) { lap_u.resize(2); lap_v.resize(2); }
        lap_u[1] = cost(0, 0);
        lap_v[1] = 0.0;
        return cost(0, 0);
    }

    const double BIG = 1e30;

    // Grow scratch buffers lazily. The first call typically arrives with the
    // largest n we'll ever see (root of the B&B); subsequent calls reuse.
    if ((int)lap_u.size() < n + 1) {
        lap_u.resize(n + 1);
        lap_v.resize(n + 1);
        lap_p.resize(n + 1);
        lap_way.resize(n + 1);
        lap_minv.resize(n + 1);
        lap_used.resize(n + 1);
    }

    if (!warm_start) {
        for (int k = 0; k <= n; ++k) { lap_u[k] = 0.0; lap_v[k] = 0.0; }
    }
    for (int k = 0; k <= n; ++k) { lap_p[k] = 0; lap_way[k] = 0; }

    for (int i = 1; i <= n; ++i) {
        for (int k = 0; k <= n; ++k) { lap_minv[k] = BIG; lap_used[k] = 0; }
        lap_p[0] = i;
        int j0 = 0;

        do {
            lap_used[j0] = 1;
            int i0 = lap_p[j0];
            double delta = BIG;
            int j1 = 0;

            for (int j = 1; j <= n; ++j) {
                if (lap_used[j]) continue;
                double cur = cost(i0 - 1, j - 1) - lap_u[i0] - lap_v[j];
                if (cur < lap_minv[j]) {
                    lap_minv[j] = cur;
                    lap_way[j]  = j0;
                }
                if (lap_minv[j] < delta) {
                    delta = lap_minv[j];
                    j1    = j;
                }
            }

            for (int j = 0; j <= n; ++j) {
                if (lap_used[j]) {
                    lap_u[lap_p[j]] += delta;
                    lap_v[j]        -= delta;
                } else {
                    lap_minv[j]     -= delta;
                }
            }

            j0 = j1;
        } while (lap_p[j0] != 0);

        do {
            int j1 = lap_way[j0];
            lap_p[j0]  = lap_p[j1];
            j0         = j1;
        } while (j0);
    }

    assignment.resize(n);
    double total = 0.0;
    for (int j = 1; j <= n; ++j) {
        assignment[lap_p[j] - 1] = j - 1;
        total += cost(lap_p[j] - 1, j - 1);
    }

    rowDual.resize(n);
    colDual.resize(n);
    for (int i = 0; i < n; ++i) {
        rowDual(i) = lap_u[i + 1];
        colDual(i) = lap_v[i + 1];
    }

    return total;
}


// ================================================================
//  Structured V^T M V and V * U for the Helmert basis V.
//
//  V (n x (n-1)) has column j made of c_j = 1/sqrt((j+1)(j+2)) in rows
//  0..j and -d_j = -(j+1) c_j in row j+1 (zeros below). This block
//  structure collapses the otherwise-dense V matmuls to O(n^2):
//
//  V^T M V at cell (k, l):
//      sum_{i=0..k+1, j=0..l+1} V[i,k] M[i,j] V[j,l]
//    = c_k c_l * Sum_{i=0..k, j=0..l} M[i,j]
//      - c_k d_l * Sum_{i=0..k} M[i, l+1]
//      - d_k c_l * Sum_{j=0..l} M[k+1, j]
//      + d_k d_l * M[k+1, l+1]
//
//  Pre-build the 2D prefix-sum table P(k, l) = Sum_{i=0..k, j=0..l} M[i, j];
//  the three rectangle sums collapse to constant-time lookups (P, and
//  P(k, l+1) - P(k, l) for the row sum, P(k+1, l) - P(k, l) for the col).
//  P itself takes O(n^2) to build, and the (n-1)^2 output cells are each
//  O(1) -- total work O(n^2) vs a dense V.transpose() * M * V at O(n^3).
//  For n = 20 this is roughly a 20x reduction in FMA ops. Used at every
//  parent's A_hat build and every child's B_hat build.
//
//  V * U at cell (i, l):
//      sum_k V[i,k] U[k,l]
//    = sum_{k=i..m-1} c_k * U[k, l]      (i > 0 entries plus the contiguous c_k block)
//      - d_{i-1} * U[i-1, l]             (row i = k+1 contribution from column i-1; 0 when i==0)
//
//  Pre-build the column suffix-sum T(i, l) = Sum_{k=i..m-1} c_k * U[k, l]
//  in O(n^2); the rank-1 correction at the second term costs O(n) per
//  column. Same 20x reduction at n = 20.
//
//  Both routines bind the c_j / d_j arrays and the prefix-sum scratch to
//  thread_local statics so the buffers grow once and never re-allocate.
//  Output bit-compatible with the dense version up to per-accumulation FP
//  reordering (well below QPB_VF_TOL_*).
// ================================================================

void QPBSolver::helmert_VTAV(const Eigen::MatrixXd& M, int n, Eigen::MatrixXd& out)
{
    if (n <= 1) { out.resize(0, 0); return; }
    out.resize(n - 1, n - 1);

    static thread_local std::vector<double> c, d;
    c.resize(n - 1);
    d.resize(n - 1);
    for (int j = 0; j < n - 1; ++j) {
        const double inv_norm = 1.0 / std::sqrt((double)(j + 1) * (j + 2));
        c[j] = inv_norm;
        d[j] = (double)(j + 1) * inv_norm;
    }

    // P(k, l) = sum_{i=0..k, j=0..l} M[i, j]. Row 0 / col 0 seeded from M,
    // interior cells from the standard inclusion-exclusion recurrence.
    static thread_local Eigen::MatrixXd P;
    P.resize(n, n);
    P(0, 0) = M(0, 0);
    for (int j = 1; j < n; ++j) P(0, j) = P(0, j - 1) + M(0, j);
    for (int i = 1; i < n; ++i) P(i, 0) = P(i - 1, 0) + M(i, 0);
    for (int i = 1; i < n; ++i)
        for (int j = 1; j < n; ++j)
            P(i, j) = P(i - 1, j) + P(i, j - 1) - P(i - 1, j - 1) + M(i, j);

    // The two edge sums fall out of differences of P. col_sum_l+1 below is
    // sum_{i=0..k} M[i, l+1]; row_sum_k+1 is sum_{j=0..l} M[k+1, j].
    for (int k = 0; k < n - 1; ++k) {
        const double c_k = c[k];
        const double d_k = d[k];
        for (int l = 0; l < n - 1; ++l) {
            const double c_l = c[l];
            const double d_l = d[l];
            const double rect      = P(k, l);
            const double col_lp1   = P(k,     l + 1) - rect;
            const double row_kp1   = P(k + 1, l    ) - rect;
            const double corner    = M(k + 1, l + 1);
            out(k, l) = c_k * c_l * rect
                      - c_k * d_l * col_lp1
                      - d_k * c_l * row_kp1
                      + d_k * d_l * corner;
        }
    }
}

void QPBSolver::helmert_VA(const Eigen::MatrixXd& U, int n, Eigen::MatrixXd& out)
{
    if (n <= 1) { out.resize(0, 0); return; }
    const int m = n - 1;
    out.resize(n, m);

    static thread_local std::vector<double> c, d;
    c.resize(m);
    d.resize(m);
    for (int j = 0; j < m; ++j) {
        const double inv_norm = 1.0 / std::sqrt((double)(j + 1) * (j + 2));
        c[j] = inv_norm;
        d[j] = (double)(j + 1) * inv_norm;
    }

    // T(i, l) = sum_{k=i..m-1} c_k * U(k, l). Sentinel row T(m, :) = 0.
    static thread_local Eigen::MatrixXd T;
    T.resize(m + 1, m);
    for (int l = 0; l < m; ++l) T(m, l) = 0.0;
    for (int i = m - 1; i >= 0; --i)
        for (int l = 0; l < m; ++l)
            T(i, l) = T(i + 1, l) + c[i] * U(i, l);

    // out(0, l) = T(0, l). For i >= 1, the row-i contribution from V's
    // -d_{i-1} entry at column i-1 needs subtracting.
    for (int l = 0; l < m; ++l) out(0, l) = T(0, l);
    for (int i = 1; i < n; ++i) {
        const double d_prev = d[i - 1];
        for (int l = 0; l < m; ++l)
            out(i, l) = T(i, l) - d_prev * U(i - 1, l);
    }
}


// ================================================================
//  Build eigendecomposition cache for A (reused across sibling nodes)
// ================================================================

void QPBSolver::buildEigenCacheA(const Eigen::MatrixXd& A, int n, QPBEigenCache& cache)
{
    cache.n = n;

    if (n <= 2) {
        // Clear shapes defensively so a consumer that reads (cache.n > 0 &&
        // ...) doesn't trip on stale data from a previous larger-n build.
        cache.W.resize(0, 0);
        cache.VW.resize(0, 0);
        cache.sigma.resize(0);
        cache.fnormFa = 0.0;
        cache.singFa.resize(0);
        return;
    }

    const int m = n - 1;

    // A_hat = V^T A V via the O(n^2) structured Helmert routine.
    Eigen::MatrixXd A_hat;
    helmert_VTAV(A, n, A_hat);
    A_hat = (0.5 * (A_hat + A_hat.transpose())).eval();

    Eigen::SelfAdjointEigenSolver<Eigen::MatrixXd> eig_A(A_hat);
    Eigen::VectorXd sigma_asc = eig_A.eigenvalues();

    cache.sigma.resize(m);
    for (int i = 0; i < m; ++i)
        cache.sigma(i) = sigma_asc(m - 1 - i);

    Eigen::MatrixXd W_asc = eig_A.eigenvectors();
    cache.W.resize(m, m);
    for (int i = 0; i < m; ++i)
        cache.W.col(i) = W_asc.col(m - 1 - i);

    // Cache V * W: pure A-side product, identical across every sibling of
    // this parent. Computed via the O(n^2) helmert_VA routine.
    helmert_VA(cache.W, n, cache.VW);

    // Cache A-side asymmetry data for compute_asym_correction's cached
    // overload (see bound_evb.hpp). fnormFa = sum of squared antisymmetric
    // entries of A; below the 1e-12 threshold A is symmetric and the SVD
    // is skipped (singFa stays empty -- the consumer short-circuits).
    cache.fnormFa = 0.0;
    for (int i = 0; i < n; ++i)
        for (int j = i + 1; j < n; ++j) {
            double diff = A(i, j) - A(j, i);
            cache.fnormFa += diff * diff;
        }
    if (cache.fnormFa >= 1e-12) {
        Eigen::MatrixXd Fa(n, n);
        for (int i = 0; i < n; ++i)
            for (int j = 0; j < n; ++j)
                Fa(i, j) = 0.5 * (A(i, j) - A(j, i));
        Eigen::JacobiSVD<Eigen::MatrixXd> svd_F(Fa);
        cache.singFa = svd_F.singularValues();
    } else {
        cache.singFa.resize(0);
    }
}


// ================================================================
//  Sinkhorn normalization (for warm-start projection)
// ================================================================

void QPBSolver::sinkhornNormalize(Eigen::MatrixXd& X, int maxIter)
{
    int n = X.rows();
    X = X.cwiseMax(0.0);

    for (int iter = 0; iter < maxIter; ++iter) {
        for (int i = 0; i < n; ++i) {
            double s = X.row(i).sum();
            if (s > 1e-15) X.row(i) /= s;
        }
        for (int j = 0; j < n; ++j) {
            double s = X.col(j).sum();
            if (s > 1e-15) X.col(j) /= s;
        }
    }
}


// ================================================================
//  Main QPB solver
// ================================================================

QPBResult QPBSolver::solve(const Eigen::MatrixXd& A, const Eigen::MatrixXd& B,
                            const Eigen::MatrixXd& C, int n,
                            const QPBParams& params,
                            double upperBound,
                            const Eigen::MatrixXd* warmStartX,
                            const QPBEigenCache* cacheA)
{
    QPBResult result;
    result.dualU = Eigen::MatrixXd::Zero(n, n);

    if (n == 0) {
        result.bound = 0.0;
        result.boundLastIter = 0.0;
        result.X.resize(0, 0);
        return result;
    }
    if (n == 1) {
        result.bound = C(0, 0);
        result.boundLastIter = C(0, 0);
        result.X = Eigen::MatrixXd::Ones(1, 1);
        return result;
    }
    if (n == 2) {
        double val_id   = A(0,0)*B(0,0) + A(0,1)*B(0,1) + A(1,0)*B(1,0) + A(1,1)*B(1,1)
                        + C(0,0) + C(1,1);
        double val_swap = A(0,0)*B(1,1) + A(0,1)*B(1,0) + A(1,0)*B(0,1) + A(1,1)*B(0,0)
                        + C(0,1) + C(1,0);
        result.bound = std::min(val_id, val_swap);
        result.boundLastIter = result.bound;
        result.X = Eigen::MatrixXd::Identity(n, n);
        return result;
    }

    const int m = n - 1;

    // ---- VW / sigma: bind to cache directly when available (no copy),
    //      otherwise build into the local fallback member buffers. V is
    //      never materialized; the structured helmert_VTAV / helmert_VA
    //      routines consume its block-structure implicitly via prefix sums
    //      (see the helmert_* function-level comments above). ----
    const Eigen::MatrixXd* VWptr;
    const Eigen::VectorXd* sigma_ptr;

    if (cacheA && cacheA->n == n) {
        VWptr     = &cacheA->VW;
        sigma_ptr = &cacheA->sigma;
    } else {
        Eigen::MatrixXd A_hat;
        helmert_VTAV(A, n, A_hat);
        A_hat = (0.5 * (A_hat + A_hat.transpose())).eval();

        Eigen::SelfAdjointEigenSolver<Eigen::MatrixXd> eig_A(A_hat);
        Eigen::VectorXd sigma_asc = eig_A.eigenvalues();
        solve_sigma_local.resize(m);
        for (int i = 0; i < m; ++i)
            solve_sigma_local(i) = sigma_asc(m - 1 - i);

        Eigen::MatrixXd W_asc = eig_A.eigenvectors();
        solve_W_local.resize(m, m);
        for (int i = 0; i < m; ++i)
            solve_W_local.col(i) = W_asc.col(m - 1 - i);

        // No A-side cache provided: compute V * W into the local fallback
        // via the structured helmert_VA routine.
        helmert_VA(solve_W_local, n, solve_VW_local);

        VWptr     = &solve_VW_local;
        sigma_ptr = &solve_sigma_local;
    }
    const Eigen::MatrixXd& VW    = *VWptr;
    const Eigen::VectorXd& sigma = *sigma_ptr;

    // ---- B_hat = V^T B V via the structured helmert_VTAV; symmetrize;
    //      eigendecompose into the persistent eigensolver. solve_eigB.compute()
    //      reuses internal tridiag / QR scratch across calls, so we avoid the
    //      per-call construction / destruction of a fresh
    //      SelfAdjointEigenSolver. ----
    helmert_VTAV(B, n, solve_Bhat);
    solve_Bhat = (0.5 * (solve_Bhat + solve_Bhat.transpose())).eval();
    solve_eigB.compute(solve_Bhat);
    // References into the eigensolver's internal storage (invalidated only on
    // the next .compute() call; we don't call .compute() again in this scope).
    const Eigen::VectorXd& lambda = solve_eigB.eigenvalues();
    const Eigen::MatrixXd& U_eig  = solve_eigB.eigenvectors();

    double gamma = 0.0;
    for (int i = 0; i < m; ++i)
        gamma += lambda(i) * sigma(i);

    // ---- s_bar, t_bar: small persistent vectors. ----
    solve_sbar.resize(m);
    solve_tbar.resize(m);
    solve_tbar(0) = 0.0;
    for (int k = 0; k < m - 1; ++k) {
        solve_sbar(k)     = lambda(k) * sigma(k) - solve_tbar(k);
        solve_tbar(k + 1) = sigma(k + 1) * (lambda(k + 1) - lambda(k)) + solve_tbar(k);
    }
    solve_sbar(m - 1) = lambda(m - 1) * sigma(m - 1) - solve_tbar(m - 1);

    // ---- VU, Sp, Tp: persistent (the big n x n / n x m matrices). ----
    //      VU = V * U_eig via the structured helmert_VA routine. U_eig is
    //      bound above as a const-ref into the eigensolver's internal
    //      storage; reading it from there here is safe because we don't
    //      call solve_eigB.compute() again in this scope.
    helmert_VA(U_eig, n, solve_VU);
    solve_Sp.noalias() = VW         * solve_sbar.asDiagonal() * VW.transpose();
    solve_Tp.noalias() = solve_VU   * solve_tbar.asDiagonal() * solve_VU.transpose();

    // ---- X init (warm-start or 1/n). ----
    if (warmStartX && warmStartX->rows() == n && warmStartX->cols() == n) {
        solve_X = *warmStartX;
    } else {
        solve_X.resize(n, n);
        solve_X.setConstant(1.0 / n);
    }

    double z_best = -1e30;
    double z_last = -1e30;

    // ---- FW-loop persistent buffers. All sized to n x n (or n) and reused
    //      across both this call's FW iters and across solve() calls. ----
    solve_G.resize(n, n);
    solve_AXB.resize(n, n);
    solve_SpX.resize(n, n);
    solve_XTp.resize(n, n);
    solve_perm_inv.resize(n);

    // LAP dual warm-start across FW iterations. After iter 0 the persistent
    // lap_u, lap_v hold optimal duals for the previous gradient G; on iter
    // k > 0 we trim them with repairLAPDuals to restore u + v <= cost
    // against the new G, then warm-start the SAP.
    bool lap_warm = false;

    // ===================================================================
    //  Two compounded sparse-direction tricks reduce FW matmul cost:
    //
    //  (1) WITHIN one FW iter (sparse-direction trick): d = P - X
    //      collapses the Qdd quadratic-form's matmuls. Where the textbook
    //      form uses four matmuls (Sp*d, A*d, (A*d)*B, d*Tp), exploiting
    //        * Q * P  = column-permutation (entry [i,k] = Q[i, perm^-1[k]])
    //        * P * Q  = row-permutation    (entry [i,j] = Q[perm[i], j])
    //      reduces them to O(n^2) permutation reads + ONE matmul for
    //      (A*P)*B (collapsing (A col-permuted) * B into a single mat-
    //      mul). The X-side products A*X*B / Sp*X / X*Tp are reused
    //      from the G step. Each Qdd term is accumulated as a single
    //      sum-of-products over the per-cell difference (M_P - M_X)
    //      rather than two separate sums, keeping cancellation per-cell
    //      and preserving ~7 decimal digits at QAP scales.
    //
    //  (2) ACROSS FW iters (recurrence trick): X_new = X + t*d gives
    //      X_new = (1-t)*X + t*P, and the X-side products evolve as
    //        A * X_new * B     = (1-t) * AXB + t * APB
    //        Sp * X_new[i,j]   = (1-t) * SpX[i,j] + t * Sp[i, perm^-1[j]]
    //        X_new * Tp[i,j]   = (1-t) * XTp[i,j] + t * Tp[perm[i], j]
    //
    //      Iter 0 still pays the four X-side matmuls (no t / perm from
    //      a prior step). After that, each iter blends solve_AXB /
    //      solve_SpX / solve_XTp in O(n^2) using t and perm / perm_inv
    //      from the previous iter; the only matmul that remains is
    //      qdd1's (A*P)*B (which the per-iter trick (1) already needs
    //      once anyway).
    //
    //      The CPU layout has solve_AXB / solve_SpX / solve_XTp /
    //      solve_APB as separate persistent buffers, so the qdd1 matmul
    //      (writes to solve_APB) doesn't clobber the X-side caches -- no
    //      scratch-slot juggling is needed (unlike the GPU kernel, where
    //      the gradient slot G has to be reused for APB and rebuilt
    //      post-loop). The column-permuted A in qdd1 is consumed lazily
    //      by Eigen's indexed view as the matmul walks its columns -- no
    //      explicit permuted-A scratch matrix is materialized.
    //
    //      Net per FW iter after iter 0: 1 matmul instead of 5. For
    //      typical FW lengths (5-15 iters) this is a ~60-75 % cut in
    //      FW matmul work, on top of trick (1). FP64 storage on CPU
    //      means the recurrence introduces no measurable drift.
    // ===================================================================

    // Across-iter recurrence state. have_prev becomes true after iter 0's
    // qdd phase runs to completion -- at that point solve_APB holds APB_0,
    // t_prev holds t_0, and solve_perm / solve_perm_inv hold iter 0's LAP
    // outputs. Iter k > 0 then blends solve_AXB / solve_SpX / solve_XTp
    // instead of recomputing them via matmuls.
    bool   have_prev = false;
    double t_prev    = 0.0;

    for (int iter = 0; iter < params.maxFW; ++iter) {

        // ---- X-side caches for this iter. ----
        //  Iter 0: full setup with four matmuls (A*X then *B = two;
        //  Sp*X; X*Tp). solve_AX is a persistent intermediate so the
        //  AXB assignment uses a non-aliasing matmul.
        //  Iter k > 0: across-iter recurrence blends in place from iter
        //  k-1's caches + APB using t_{k-1} and perm / perm_inv from
        //  iter k-1 (which still hold their previous-iter values --
        //  iter k's LAP runs below, AFTER the recurrence).
        if (!have_prev) {
            solve_AX.noalias()  = A          * solve_X;
            solve_AXB.noalias() = solve_AX   * B;
            solve_SpX.noalias() = solve_Sp   * solve_X;
            solve_XTp.noalias() = solve_X    * solve_Tp;
        } else {
            const double one_minus_t = 1.0 - t_prev;

            // solve_AXB <- (1 - t) * solve_AXB + t * solve_APB.
            //  Self-aliased assignment on a coefficient-wise expression;
            //  Eigen evaluates correctly without an explicit temporary.
            solve_AXB = one_minus_t * solve_AXB + t_prev * solve_APB;

            // solve_SpX <- (1 - t) * solve_SpX + t * Sp[:, perm_inv].
            // solve_XTp <- (1 - t) * solve_XTp + t * Tp[perm, :].
            //  Eigen 3.4 indexed views: solve_Sp(Eigen::all, perm_inv_v)
            //  is a non-owning expression representing the column-permuted
            //  Sp; solve_Tp(perm_v, Eigen::all) is row-permuted Tp. The
            //  composite coefficient-wise expression lets Eigen vectorize
            //  the lerp per column (SpX: contiguous column reads, gather
            //  by output index) and per row (XTp: strided row reads at
            //  stride n; less ideal in column-major but still expressed
            //  as one expression for the optimizer).
            Eigen::Map<const Eigen::VectorXi> perm_inv_v(solve_perm_inv.data(), n);
            Eigen::Map<const Eigen::VectorXi> perm_v    (solve_perm.data(),     n);
            solve_SpX = one_minus_t * solve_SpX + t_prev * solve_Sp(Eigen::all, perm_inv_v);
            solve_XTp = one_minus_t * solve_XTp + t_prev * solve_Tp(perm_v,     Eigen::all);
        }

        // ---- G = 2 * (AXB - SpX - XTp) + C. Always rebuilt from caches. ----
        solve_G = 2.0 * (solve_AXB - solve_SpX - solve_XTp) + C;

        // ---- LAP. Warm-start from the previous iter's u, v if available,
        //      after restoring feasibility against the new G. ----
        if (lap_warm) {
            repairLAPDuals(solve_G, n);
        }
        solveLAPDouble(solve_G, n, solve_perm, solve_lapRowDual, solve_lapColDual, lap_warm);
        lap_warm = true;

        double GdotX = solve_G.cwiseProduct(solve_X).sum();
        double CdotX = C.cwiseProduct(solve_X).sum();
        double fX    = 0.5 * (GdotX + CdotX) + gamma;

        double GdotY = 0.0;
        for (int i = 0; i < n; ++i)
            GdotY += solve_G(i, solve_perm[i]);

        double fw_gap = GdotY - GdotX;

        double z = fX + fw_gap;
        z_best = std::max(z_best, z);
        z_last = z;

        if (std::ceil(z_best - 1e-6) >= upperBound)
            break;

        if (-fw_gap < params.tol * std::max(1.0, std::abs(fX)))
            break;

        // ---- d = perm_matrix - X. Materialize for the per-cell dot products. ----
        solve_d = -solve_X;
        for (int i = 0; i < n; ++i)
            solve_d(i, solve_perm[i]) += 1.0;

        // ---- Inverse permutation for the column-permutation reads. ----
        for (int i = 0; i < n; ++i) solve_perm_inv[solve_perm[i]] = i;

        // ---- qdd2 = <d, Sp*d> = <d, Sp*P - Sp*X>.
        //      Sp*P is the column-permutation of Sp:
        //      (Sp*P)[i, j] = Sp[i, perm_inv[j]]. ----
        double qdd2 = 0.0;
        for (int i = 0; i < n; ++i) {
            for (int j = 0; j < n; ++j) {
                qdd2 += solve_d(i, j) * (solve_Sp(i, solve_perm_inv[j]) - solve_SpX(i, j));
            }
        }

        // ---- qdd3 = <d, d*Tp> = <d, P*Tp - X*Tp>.
        //      P*Tp is the row-permutation of Tp:
        //      (P*Tp)[i, j] = Tp[perm[i], j]. ----
        double qdd3 = 0.0;
        for (int i = 0; i < n; ++i) {
            int pi = solve_perm[i];
            for (int j = 0; j < n; ++j) {
                qdd3 += solve_d(i, j) * (solve_Tp(pi, j) - solve_XTp(i, j));
            }
        }

        // ---- qdd1 = <d, A*d*B> = <d, A*P*B - A*X*B>.
        //      A*P is column-permutation of A:
        //      (A*P)[i, k] = A[i, perm_inv[k]]; then (A*P)*B is one matmul.
        //      AXB is the cache from the G step above. solve_APB also feeds
        //      the across-iter recurrence's solve_AXB blend at iter+1 start.
        //
        //      Indexed-view fusion: instead of materializing the column-
        //      permuted A into solve_AP and then multiplying by B, hand Eigen
        //      the expression A(Eigen::all, perm_inv_v) * B directly. Eigen
        //      evaluates the indexed columns lazily as it walks the matmul
        //      kernel, saving the O(n^2) write + read pass through solve_AP.
        //      The same Map<const VectorXi> pattern is already used for the
        //      across-iter T1 / T3 blends at the top of the loop, so the
        //      slicing path is well-trodden here. -
        Eigen::Map<const Eigen::VectorXi> perm_inv_v_qdd1(solve_perm_inv.data(), n);
        solve_APB.noalias() = A(Eigen::all, perm_inv_v_qdd1) * B; // matmul 5 of this iter

        double qdd1 = 0.0;
        for (int i = 0; i < n; ++i) {
            for (int j = 0; j < n; ++j) {
                qdd1 += solve_d(i, j) * (solve_APB(i, j) - solve_AXB(i, j));
            }
        }

        double Qdd = qdd1 - qdd2 - qdd3;

        double t;
        if (Qdd > 1e-12)
            t = std::min(1.0, std::max(0.0, -fw_gap / (2.0 * Qdd)));
        else
            t = 1.0;

        solve_X += t * solve_d;

        // ---- Latch state for the next iter's recurrence. ----
        t_prev    = t;
        have_prev = true;
    }

    result.bound = z_best;
    result.boundLastIter = z_last;
    result.X     = solve_X;   // one unavoidable copy: caller stores X in the child node

    result.dualU.resize(n, n);
    for (int i = 0; i < n; ++i)
        for (int j = 0; j < n; ++j)
            result.dualU(i, j) = solve_G(i, j) - solve_lapRowDual(i) - solve_lapColDual(j);

    return result;
}


// ================================================================
//  Extract warm-start for child node
// ================================================================

void QPBSolver::extractWarmStart(const Eigen::MatrixXd& parentX, int ri, int ci,
                                  Eigen::MatrixXd& out)
{
    int m = parentX.rows();
    int mc = m - 1;
    out.resize(mc, mc);

    int r2 = 0;
    for (int r = 0; r < m; ++r) {
        if (r == ri) continue;
        int c2 = 0;
        for (int c = 0; c < m; ++c) {
            if (c == ci) continue;
            out(r2, c2) = parentX(r, c);
            c2++;
        }
        r2++;
    }

    // Sinkhorn projection back onto the Birkhoff polytope after stripping
    // the parent's row/column. 5 iterations is calibrated: the parent's X
    // is already near-doubly-stochastic, so 3 to 5 sweeps are enough to
    // restore the constraint within tolerance. Lower counts weaken the
    // continuous bound and add visited nodes; higher counts are unnecessary
    // work. Matches the GPU's qpb_sinkIter default.
    sinkhornNormalize(out, 5);
}


//--------------------------------------------- QPB (B&B free-function interface) -----------------------------------------------

longint bound_QPB (const vector<int>& mapping, const vector<bool>& available, int depth,
                   const vector<int>& F, const vector<int>& D, int n, int N,
                   QPBSolver& solver, const QPBParams& params, longint upperBound,
                   bool f_symmetric, bool d_symmetric)
{
    //----- Identify assigned and unassigned facilities/locations -----
    vector<int> assigned_fac, unassigned_fac, unassigned_loc;

    for (int i = 0; i < n; ++i)
    {
        if (mapping[i] != -1)
            assigned_fac.push_back(i);
        else
            unassigned_fac.push_back(i);
    }
    for (int k = 0; k < N; ++k)
    {
        if (available[k])
            unassigned_loc.push_back(k);
    }

    int m = (int) unassigned_fac.size();
    int p = (int) unassigned_loc.size();

    //----- Fixed cost -----
    longint fixed_cost = Objective(mapping, F, D, n, N);

    if (m == 0)
        return fixed_cost;

    //----- QPB requires square sub-problems (m == p) -----
    if (m != p)
        return bound_GLB(mapping, available, depth, F, D, n, N);

    //----- Build sub-matrices A' (m x m), B' (m x m), C' (m x m) -----
    Eigen::MatrixXd A_sub(m, m), B_sub(m, m), C_sub(m, m);

    for (int i = 0; i < m; ++i)
        for (int j = 0; j < m; ++j)
            A_sub(i, j) = F[unassigned_fac[i] * N + unassigned_fac[j]];

    for (int i = 0; i < m; ++i)
        for (int j = 0; j < m; ++j)
            B_sub(i, j) = D[unassigned_loc[i] * N + unassigned_loc[j]];

    for (int i_idx = 0; i_idx < m; ++i_idx)
    {
        int i = unassigned_fac[i_idx];

        for (int k_idx = 0; k_idx < m; ++k_idx)
        {
            int k = unassigned_loc[k_idx];
            double cross = 0.0;

            for (int a_idx = 0; a_idx < (int) assigned_fac.size(); ++a_idx)
            {
                int a = assigned_fac[a_idx];
                int b = mapping[a];

                cross += (double) F[i * N + a] * D[k * N + b];
                cross += (double) F[a * N + i] * D[b * N + k];
            }

            C_sub(i_idx, k_idx) = cross;
        }
    }

    //----- Asymmetry correction (must be computed before symmetrizing) -----
    double asym_correction = compute_asym_correction(A_sub, B_sub, m, m);

    //----- Symmetrize A_sub and B_sub. Skipped when the full F / D was
    //      verified symmetric at startup: every F submatrix is then exactly
    //      symmetric after the int->double cast, so the `.eval()` materialize
    //      is pure overhead. -----
    if (!f_symmetric)
        A_sub = (0.5 * (A_sub + A_sub.transpose())).eval();
    if (!d_symmetric)
        B_sub = (0.5 * (B_sub + B_sub.transpose())).eval();

    //----- Solve QPB (no warm-start or cache in free-function mode) -----
    QPBResult res = solver.solve(A_sub, B_sub, C_sub, m, params,
                                  (double)(upperBound - fixed_cost),
                                  nullptr, nullptr);

    //----- Combine: fixed_cost + ceil(QPB bound + asymmetry correction) -----
    double corrected = res.bound + asym_correction;
    double lb_tol = std::max(QPB_VF_TOL_BASE, QPB_VF_TOL_REL * std::abs(corrected));
    longint remaining_lb = static_cast<longint>(std::ceil(corrected - lb_tol));

    return fixed_cost + remaining_lb;
}
