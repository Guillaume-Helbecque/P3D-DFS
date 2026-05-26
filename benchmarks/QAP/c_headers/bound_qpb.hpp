#ifndef __QPB_BOUND__
    #define __QPB_BOUND__

    #include "utils.hpp"
    #include <Eigen/Dense>

    // Parameters for the QPB Frank-Wolfe solver.
    struct QPBParams {
        int    maxFW  = 50;     // maximum Frank-Wolfe iterations
        double tol    = 1e-5;   // convergence tolerance (relative FW duality gap)
    };

    // QPB integer-bound roundoff envelope (CPU side). Drives two operations:
    //
    //   (1) Variable-fixing prune (CPU drivers, node.cpp / main_mpi.cpp):
    //         est    = parent.qpbFixedCost + parent.qpbBoundContLast
    //                  + parent.qpbReducedCosts(i_idx, j_idx)
    //         vf_tol = max(BASE, REL * |est|)
    //         prune if ceil(est - vf_tol) >= UB
    //
    //   (2) Integer floor on the QPB bound (bound_qpb.cpp's bound_QPB,
    //       and the CPU decompose's lb_child computation):
    //         corrected = res.bound + asym_correction
    //         lb_tol    = max(BASE, REL * |corrected|)
    //         remaining_lb = ceil(corrected - lb_tol)
    //
    // Both apply to FP64-stored CPU bounds, so the envelope is tighter than
    // the GPU's looser FP32-storage constants (see bound_qpb_gpu.cu and the
    // GPU drivers for the GPU values + their rationale). Do NOT tighten
    // without an instance-aware analysis of the actual roundoff envelope on
    // each target instance class: tolerances below the true envelope prune
    // legitimate optimum-bearing subtrees and silently break correctness.
    constexpr double QPB_VF_TOL_BASE = 1e-6;
    constexpr double QPB_VF_TOL_REL  = 1e-7;

    // Result of QPB computation.
    struct QPBResult {
        double bound;                // QPB lower bound (best across all FW iterations)
        double boundLastIter;        // bound from last FW iteration
        Eigen::MatrixXd X;           // primal doubly stochastic solution
        Eigen::MatrixXd dualU;       // dual reduced-cost matrix
    };

    // Cached eigendecomposition of A_hat for reuse across sibling nodes.
    // All sibling subproblems of one parent share the same A submatrix
    // (siblings branch on the same facility, only the location differs),
    // so the A-side data is computed once per parent and reused.
    //
    //   W, sigma : eigendecomposition of V^T A V (descending).
    //   VW       : V * W, the matrix used in the Sp = VW * sbar_diag * VW^T
    //              build. Pure function of A, hence cached.
    //   fnormFa, singFa : asymmetry-correction data (||Fa||_F^2 and
    //              singular values of Fa = 0.5(A - A^T)). Only meaningful
    //              for asymmetric instances (tai-style); for symmetric
    //              instances fnormFa is below the threshold and the
    //              consumer short-circuits before the SVD.
    //
    // V itself (the Helmert basis) is never materialized: helmert_VTAV /
    // helmert_VA consume V's block structure implicitly via prefix sums.
    struct QPBEigenCache {
        Eigen::MatrixXd W;       // (n-1) x (n-1) eigenvectors of A_hat
        Eigen::MatrixXd VW;      // n x (n-1) cached V * W (reused across siblings)
        Eigen::VectorXd sigma;   // eigenvalues of A_hat (descending)
        double fnormFa = 0.0;    // ||Fa||_F^2, where Fa = 0.5 (A - A^T)
        Eigen::VectorXd singFa;  // singular values of Fa (empty if fnormFa below threshold)
        int n = 0;               // problem size (0 = invalid/empty)
    };

    // QPB solver class (Frank-Wolfe on Birkhoff polytope with SDD dual)
    //
    //  Non-thread-safe: one instance per worker (the CPU drivers instantiate
    //  one QPBSolver per MPI rank, and there is no OpenMP usage inside the
    //  QPB hot path). The LAP scratch buffers below are kept alive as
    //  instance members so the inner LAP loop doesn't malloc/free on every
    //  row of every FW iter (which it would if they were function-local).
    //  Sized lazily on the first call; reused thereafter.
    class QPBSolver {
    public:
        QPBResult solve(const Eigen::MatrixXd& A, const Eigen::MatrixXd& B,
                        const Eigen::MatrixXd& C, int n, const QPBParams& params,
                        double upperBound = 1e30,
                        const Eigen::MatrixXd* warmStartX = nullptr,
                        const QPBEigenCache* cacheA = nullptr);

        // In-place builders: write into `cache` / `out` (resized as needed).
        // Callers recycle a persistent destination across decompose calls so
        // the per-call Eigen allocations for W / VW / sigma / singFa and the
        // warm-start X collapse to a single matching-size reuse after the
        // first call.
        static void buildEigenCacheA(const Eigen::MatrixXd& A, int n, QPBEigenCache& cache);
        static void sinkhornNormalize(Eigen::MatrixXd& X, int maxIter = 20);
        static void extractWarmStart(const Eigen::MatrixXd& parentX, int ri, int ci,
                                      Eigen::MatrixXd& out);

    private:
        // Structured V^T M V and V * U routines that exploit the Helmert
        // basis V's per-column block structure to compute the result in
        // O(n^2) instead of the O(n^3) of dense matmul.
        //
        //   V has shape n x (n-1); column j has c_j = 1/sqrt((j+1)(j+2))
        //   for rows i in 0..j and -(j+1) c_j at row j+1, with zeros below.
        //   helmert_VTAV evaluates each output cell via a 2D prefix sum of
        //   M plus three corner / edge corrections; helmert_VA evaluates
        //   each output cell via a column suffix sum of c_k * U(k, l) plus
        //   one rank-1 correction. Both routines hold their intermediate
        //   sums in thread_local scratch so calls of matching size never
        //   re-allocate. The result is equivalent to V^T M V and V * U
        //   up to FP roundoff in the accumulation order.
        //
        // out is resized as needed: (n-1) x (n-1) for helmert_VTAV and
        // n x (n-1) for helmert_VA. V itself is never materialized.
        static void helmert_VTAV(const Eigen::MatrixXd& M, int n, Eigen::MatrixXd& out);
        static void helmert_VA  (const Eigen::MatrixXd& U, int n, Eigen::MatrixXd& out);

        // Jonker-Volgenant LAP. Now non-static so it can reuse the persistent
        // scratch buffers below. `warm_start` controls whether the row duals
        // u and column duals v are zero-initialised (false: cold) or kept
        // from the previous call on a different cost matrix (true: warm,
        // caller is responsible for restoring u+v <= cost feasibility via
        // repairLAPDuals before this call -- see solve()'s FW loop).
        double solveLAPDouble(const Eigen::MatrixXd& cost, int n,
                              std::vector<int>& assignment,
                              Eigen::VectorXd& rowDual,
                              Eigen::VectorXd& colDual,
                              bool warm_start = false);

        // Bidirectional LAP dual repair for warm-starting against a changed
        // cost matrix. Runs in two O(n^2) phases:
        //
        //   Phase 1 (row trim): for each row i, decrements u[i] by
        //     max(0, max_j(u[i]+v[j]-c[i,j])) so feasibility u+v <= c holds.
        //     Each row with a positive violation becomes tight at the argmax j.
        //
        //   Phase 2 (column tighten): for each col j, raises v[j] to its max
        //     feasible value min_i(c[i,j] - u[i]). After Phase 1, current v[j]
        //     is already feasible (= upper-bounded by every c[i,j]-u[i]), so
        //     this can only INCREASE v[j]. Each column becomes tight at the
        //     argmin i, in addition to the row-tight pairs from Phase 1.
        //
        // The bidirectional version trades 2 n^2 work for a closer starting
        // point to the new G's optimal duals -- the subsequent SAP converges
        // in fewer augmentation steps per row than with row-only repair. Net
        // saving despite the larger pre-step. Still O(n^2), still much cheaper
        // than the O(n^3) SAP whose warm-start it enables.
        void repairLAPDuals(const Eigen::MatrixXd& cost, int n);

        // Persistent LAP scratch (1-based indexing, so size = n + 1). All six
        // grow as needed on the first solveLAPDouble call of a given n and
        // are reused for every subsequent call. `char` rather than `bool` for
        // `used` because std::vector<bool> is the bit-packed specialisation
        // and per-element access is measurably slower than byte storage.
        std::vector<double> lap_u, lap_v, lap_minv;
        std::vector<int>    lap_p, lap_way;
        std::vector<char>   lap_used;

        // Persistent solve() buffers. Same rationale as the LAP scratch
        // above: each buffer is sized lazily on first use; Eigen reuses
        // storage when assigned to a same-size matrix, so subsequent calls
        // with matching n incur no realloc. The eigensolver is reused via
        // .compute(), which keeps its internal tridiagonal / QR scratch
        // across calls.
        //
        //   solve_eigB / solve_Bhat       : B-side eigendecomp.
        //   solve_VU / solve_Sp / solve_Tp: setup outputs.
        //   solve_X / solve_G             : primal iterate / gradient.
        //   solve_AXB / solve_SpX / solve_XTp : X-side caches consumed by
        //                                       the FW across-iter recurrence.
        //   solve_AX                      : A * X intermediate at FW iter 0.
        //   solve_d                       : FW step direction (P - X).
        //   solve_APB                     : (A * P) * B, carried into the
        //                                   next iter's recurrence start.
        //   solve_sbar / solve_tbar       : SDD coefficient vectors.
        //   solve_lapRowDual / solve_lapColDual : LAP duals captured for
        //                                         the post-FW reduced-cost
        //                                         readout.
        //   solve_perm / solve_perm_inv   : LAP permutation and its inverse.
        Eigen::SelfAdjointEigenSolver<Eigen::MatrixXd> solve_eigB;
        Eigen::MatrixXd solve_Bhat;
        Eigen::MatrixXd solve_VU;
        Eigen::MatrixXd solve_Sp, solve_Tp;
        Eigen::MatrixXd solve_X, solve_G;
        Eigen::MatrixXd solve_AXB, solve_SpX, solve_XTp;
        Eigen::MatrixXd solve_AX, solve_d, solve_APB;
        Eigen::VectorXd solve_sbar, solve_tbar;
        Eigen::VectorXd solve_lapRowDual, solve_lapColDual;
        std::vector<int> solve_perm, solve_perm_inv;

        // Local fallback buffers for W / VW / sigma when no QPBEigenCache is
        // provided. When a cache is provided, solve() reads its matrices via
        // const refs (no deep-copy on the cache-hit path). V is not stored
        // anywhere: the structured helmert_* routines consume it implicitly.
        Eigen::MatrixXd solve_W_local, solve_VW_local;
        Eigen::VectorXd solve_sigma_local;
    };

    // QPB lower bound (free-function interface, simple signature for NVCC compatibility).
    //
    // f_symmetric / d_symmetric: when true, the caller has verified that the
    // full F / D matrix is exactly integer-symmetric; the function then skips
    // the per-child A_sub / B_sub `(0.5 * (M + M^T)).eval()` step (those sub-
    // matrices inherit exact symmetry from F / D in that case). Defaults to
    // false (unconditional symmetrization) for callers that haven't run the
    // probe.
    longint bound_QPB(const std::vector<int>& mapping,
                      const std::vector<bool>& available,
                      int depth,
                      const std::vector<int>& F,
                      const std::vector<int>& D,
                      int n, int N,
                      QPBSolver& solver,
                      const QPBParams& params,
                      longint upperBound = INF,
                      bool f_symmetric = false,
                      bool d_symmetric = false);

#endif
