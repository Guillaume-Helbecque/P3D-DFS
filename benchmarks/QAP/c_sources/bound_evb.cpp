#include "../c_headers/bound_evb.hpp"
#include "../c_headers/objective.hpp"


//=============================================================================
// Double-precision O(n^3) Hungarian algorithm (Jonker-Volgenant style)
//=============================================================================

double hungarian_double (const Eigen::MatrixXd& cost, int n, std::vector<int>& assignment)
{
    const double BIG = 1e30;

    std::vector<double> u(n + 1, 0.0), v(n + 1, 0.0);
    std::vector<int> p(n + 1, 0), way(n + 1, 0);

    for (int i = 1; i <= n; ++i)
    {
        p[0] = i;
        int j0 = 0;
        std::vector<double> minv(n + 1, BIG);
        std::vector<bool> used(n + 1, false);

        do {
            used[j0] = true;
            int i0 = p[j0];
            double delta = BIG;
            int j1 = -1;

            for (int j = 1; j <= n; ++j)
            {
                if (used[j]) continue;

                double cur = cost(i0 - 1, j - 1) - u[i0] - v[j];
                if (cur < minv[j])
                {
                    minv[j] = cur;
                    way[j] = j0;
                }
                if (minv[j] < delta)
                {
                    delta = minv[j];
                    j1 = j;
                }
            }

            for (int j = 0; j <= n; ++j)
            {
                if (used[j])
                {
                    u[p[j]] += delta;
                    v[j] -= delta;
                }
                else
                {
                    minv[j] -= delta;
                }
            }

            j0 = j1;
        } while (p[j0] != 0);

        do {
            int j1 = way[j0];
            p[j0] = p[j1];
            j0 = j1;
        } while (j0);
    }

    assignment.resize(n);
    double total = 0.0;

    for (int j = 1; j <= n; ++j)
    {
        if (p[j] != 0)
        {
            assignment[p[j] - 1] = j - 1;
            total += cost(p[j] - 1, j - 1);
        }
    }

    return total;
}


//=============================================================================
// Asymmetry correction: -sum_k sigma_k(F_a) * sigma_k(D_a)
//=============================================================================

double compute_asym_correction (const Eigen::MatrixXd& F_sub, const Eigen::MatrixXd& D_sub,
                                int m, int p)
{
    double fnorm_Fa = 0.0, fnorm_Da = 0.0;

    for (int i = 0; i < m; ++i)
        for (int j = i + 1; j < m; ++j)
        {
            double diff = F_sub(i, j) - F_sub(j, i);
            fnorm_Fa += diff * diff;
        }

    for (int i = 0; i < p; ++i)
        for (int j = i + 1; j < p; ++j)
        {
            double diff = D_sub(i, j) - D_sub(j, i);
            fnorm_Da += diff * diff;
        }

    if (fnorm_Fa < 1e-12 || fnorm_Da < 1e-12)
        return 0.0;

    Eigen::MatrixXd F_a(m, m), D_a(p, p);

    for (int i = 0; i < m; ++i)
        for (int j = 0; j < m; ++j)
            F_a(i, j) = 0.5 * (F_sub(i, j) - F_sub(j, i));

    for (int i = 0; i < p; ++i)
        for (int j = 0; j < p; ++j)
            D_a(i, j) = 0.5 * (D_sub(i, j) - D_sub(j, i));

    Eigen::JacobiSVD<Eigen::MatrixXd> svd_F(F_a);
    Eigen::JacobiSVD<Eigen::MatrixXd> svd_D(D_a);

    Eigen::VectorXd sv_F = svd_F.singularValues();
    Eigen::VectorXd sv_D = svd_D.singularValues();

    double asym_norm = 0.0;
    int pairs = std::min((int) sv_F.size(), (int) sv_D.size());

    for (int k = 0; k < pairs; ++k)
        asym_norm += sv_F(k) * sv_D(k);

    return -asym_norm;
}


//=============================================================================
// Cached overload of compute_asym_correction.
//
// Reuses the F-side data (cached_fnormFa, cached_singFa) precomputed once
// per parent in QPBSolver::buildEigenCacheA (siblings share the same F).
// Builds the D-side fresh because D varies per sibling. Bit-exact match
// with the non-cached overload when called with the same F matrix --
// both paths use Eigen::JacobiSVD on the same F_a.
//=============================================================================

double compute_asym_correction (double cached_fnormFa,
                                const Eigen::VectorXd& cached_singFa,
                                const Eigen::MatrixXd& D_sub, int p)
{
    // F symmetric -> no correction at all (skips per-child D-side too).
    if (cached_fnormFa < 1e-12)
        return 0.0;

    // D side (per-child).
    double fnorm_Da = 0.0;
    for (int i = 0; i < p; ++i)
        for (int j = i + 1; j < p; ++j)
        {
            double diff = D_sub(i, j) - D_sub(j, i);
            fnorm_Da += diff * diff;
        }
    if (fnorm_Da < 1e-12)
        return 0.0;

    Eigen::MatrixXd D_a(p, p);
    for (int i = 0; i < p; ++i)
        for (int j = 0; j < p; ++j)
            D_a(i, j) = 0.5 * (D_sub(i, j) - D_sub(j, i));

    Eigen::JacobiSVD<Eigen::MatrixXd> svd_D(D_a);
    Eigen::VectorXd sv_D = svd_D.singularValues();

    double asym_norm = 0.0;
    int pairs = std::min((int) cached_singFa.size(), (int) sv_D.size());

    for (int k = 0; k < pairs; ++k)
        asym_norm += cached_singFa(k) * sv_D(k);

    return -asym_norm;
}


//=============================================================================
// Minimal scalar product: pair eigenvalues of A (desc) with eigenvalues of B (asc)
//=============================================================================

static double min_scalar_product (const Eigen::VectorXd& ev_A, const Eigen::VectorXd& ev_B)
{
    int nA = (int) ev_A.size();
    int nB = (int) ev_B.size();
    int pairs = std::min(nA, nB);

    double sum = 0.0;
    for (int k = 0; k < pairs; ++k)
        sum += ev_A(nA - 1 - k) * ev_B(k);

    return sum;
}


//=============================================================================
// EVB3: iterative eigenvalue bound (square case, m == p)
//=============================================================================

double compute_evb3 (const Eigen::MatrixXd& F_sub, const Eigen::MatrixXd& D_sub,
                     const Eigen::MatrixXd& C_cross, double asym_correction, int m,
                     double ub_target)
{
    if (m <= 1)
    {
        if (m == 1)
            return F_sub(0, 0) * D_sub(0, 0) + C_cross(0, 0);
        return 0.0;
    }

    int n = m;

    Eigen::MatrixXd F_s = 0.5 * (F_sub + F_sub.transpose());
    Eigen::MatrixXd D_s = 0.5 * (D_sub + D_sub.transpose());

    Eigen::VectorXd a(n), b(n);
    for (int i = 0; i < n; ++i) a(i) = F_s(i, i);
    for (int i = 0; i < n; ++i) b(i) = D_s(i, i);

    Eigen::MatrixXd A = F_s;
    A.diagonal().setZero();
    Eigen::MatrixXd B = D_s;
    B.diagonal().setZero();

    Eigen::VectorXd rA = A.rowwise().sum();
    double sA = rA.sum();

    Eigen::VectorXd e = Eigen::VectorXd::Zero(n);
    Eigen::VectorXd g = Eigen::VectorXd::Zero(n);
    Eigen::VectorXd s = Eigen::VectorXd::Zero(n);

    Eigen::VectorXd r(n);
    for (int i = 0; i < n; ++i)
        r(i) = (-2.0 * rA(i) + sA / n) / (n - 1);

    Eigen::MatrixXd LAP_const = C_cross;
    for (int i = 0; i < n; ++i)
        for (int k = 0; k < n; ++k)
            LAP_const(i, k) += a(i) * b(k);

    double best_bound = -1e30;
    int max_iter = 50;
    double lambda = 2.0;
    int no_improve_count = 0;
    int halvings = 0;
    bool use_polyak = (ub_target < 1e29);

    Eigen::VectorXd beta_rev(n), alpha_rev(n);
    std::vector<int> pi_star, inv_pi(n);

    for (int iter = 0; iter < max_iter; ++iter)
    {
        Eigen::MatrixXd A_tilde = A;
        Eigen::MatrixXd B_tilde = B;

        A_tilde.colwise() -= e;
        A_tilde.rowwise() -= e.transpose();
        A_tilde.diagonal() -= r;

        B_tilde.colwise() -= g;
        B_tilde.rowwise() -= g.transpose();
        B_tilde.diagonal() -= s;

        Eigen::SelfAdjointEigenSolver<Eigen::MatrixXd> eig_A(A_tilde);
        Eigen::SelfAdjointEigenSolver<Eigen::MatrixXd> eig_B(B_tilde);

        const Eigen::VectorXd& alpha = eig_A.eigenvalues();
        const Eigen::VectorXd& beta  = eig_B.eigenvalues();
        const Eigen::MatrixXd& P = eig_A.eigenvectors();
        const Eigen::MatrixXd& Q = eig_B.eigenvectors();

        double eig_bound = min_scalar_product(alpha, beta);

        Eigen::VectorXd rA_tilde = A_tilde.rowwise().sum();
        Eigen::VectorXd rB_tilde = B_tilde.rowwise().sum();

        Eigen::VectorXd B_diag = B_tilde.diagonal();
        Eigen::VectorXd A_diag = A_tilde.diagonal();
        Eigen::VectorXd col_r = B_diag + 2.0 * g + s;
        Eigen::VectorXd col_e = rB_tilde + (double)n * g + s;

        Eigen::MatrixXd LAP = r * col_r.transpose()
                             + 2.0 * e * col_e.transpose()
                             + 2.0 * rA_tilde * g.transpose()
                             + A_diag * s.transpose()
                             + LAP_const;

        double lap_val = hungarian_double(LAP, n, pi_star);

        double sum_e = e.sum();
        double sum_g = g.sum();
        double bound = eig_bound + lap_val + 2.0 * sum_e * sum_g + asym_correction;

        if (bound > best_bound + 1e-10)
        {
            best_bound = bound;
            no_improve_count = 0;
        }
        else
        {
            no_improve_count++;
        }

        if (no_improve_count >= 3)
        {
            lambda *= 0.5;
            no_improve_count = 0;
            halvings++;
        }

        if (lambda < 1e-4 || halvings >= 8)
            break;

        if (iter == max_iter - 1)
            break;

        for (int j = 0; j < n; ++j)
        {
            beta_rev(j)  = beta(n - 1 - j);
            alpha_rev(j) = alpha(n - 1 - j);
        }

        Eigen::VectorXd SA = P.colwise().sum().transpose();
        Eigen::VectorXd SB = Q.colwise().sum().transpose();

        for (int i = 0; i < n; ++i)
            inv_pi[pi_star[i]] = i;

        Eigen::VectorXd grad_r = -(P.array().square().matrix()) * beta_rev;
        for (int i = 0; i < n; ++i)
            grad_r(i) += B_tilde(pi_star[i], pi_star[i]);

        Eigen::VectorXd grad_s = -(Q.array().square().matrix()) * alpha_rev;
        for (int i = 0; i < n; ++i)
            grad_s(i) += A_tilde(inv_pi[i], inv_pi[i]);

        Eigen::VectorXd grad_e = -2.0 * P * beta_rev.cwiseProduct(SA);
        for (int i = 0; i < n; ++i)
            grad_e(i) += 2.0 * rB_tilde(pi_star[i]);

        Eigen::VectorXd grad_g = -2.0 * Q * alpha_rev.cwiseProduct(SB);
        for (int i = 0; i < n; ++i)
            grad_g(i) += 2.0 * rA_tilde(inv_pi[i]);

        double grad_norm_sq = grad_r.squaredNorm() + grad_s.squaredNorm()
                            + grad_e.squaredNorm() + grad_g.squaredNorm();

        if (grad_norm_sq < 1e-16)
            break;

        double t;
        if (use_polyak)
        {
            double gap = ub_target - best_bound;
            if (gap <= 0.0)
                break;
            t = lambda * gap / grad_norm_sq;
        }
        else
        {
            t = lambda / std::sqrt(grad_norm_sq);
        }

        r += t * grad_r;
        s += t * grad_s;
        e += t * grad_e;
        g += t * grad_g;
    }

    return best_bound;
}


//=============================================================================
// Basic eigenvalue bound for rectangular sub-problems (m < p)
//=============================================================================

double compute_evb_rect (const Eigen::MatrixXd& F_sub, const Eigen::MatrixXd& D_sub,
                         const Eigen::MatrixXd& C_cross, double asym_correction, int m, int p)
{
    if (m <= 0)
        return 0.0;

    if (m == 1)
    {
        double min_val = 1e30;
        for (int k = 0; k < p; ++k)
        {
            double val = F_sub(0, 0) * D_sub(k, k) + C_cross(0, k);
            min_val = std::min(min_val, val);
        }
        return min_val;
    }

    Eigen::MatrixXd F_s = 0.5 * (F_sub + F_sub.transpose());
    Eigen::MatrixXd D_s = 0.5 * (D_sub + D_sub.transpose());

    Eigen::VectorXd a(m), b(p);
    for (int i = 0; i < m; ++i) a(i) = F_s(i, i);
    for (int i = 0; i < p; ++i) b(i) = D_s(i, i);

    Eigen::MatrixXd F0 = F_s;
    F0.diagonal().setZero();
    Eigen::MatrixXd D0 = D_s;
    D0.diagonal().setZero();

    Eigen::SelfAdjointEigenSolver<Eigen::MatrixXd> eig_F(F0);
    Eigen::SelfAdjointEigenSolver<Eigen::MatrixXd> eig_D(D0);

    const Eigen::VectorXd& ev_F = eig_F.eigenvalues();
    const Eigen::VectorXd& ev_D = eig_D.eigenvalues();

    double eig_bound = 0.0;
    for (int k = 0; k < m; ++k)
        eig_bound += ev_F(m - 1 - k) * ev_D(k);

    Eigen::MatrixXd LAP = Eigen::MatrixXd::Zero(p, p);

    for (int i = 0; i < m; ++i)
        for (int k = 0; k < p; ++k)
            LAP(i, k) = a(i) * b(k) + C_cross(i, k);

    std::vector<int> pi_star;
    double lap_val = hungarian_double(LAP, p, pi_star);

    return eig_bound + lap_val + asym_correction;
}


//--------------------------------------------- EVB (B&B interface) -----------------------------------------------

longint bound_EVB (const vector<int>& mapping, const vector<bool>& available, int depth,
                   const vector<int>& F, const vector<int>& D, int n, int N,
                   longint ub)
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

    //----- Build sub-matrices -----
    Eigen::MatrixXd F_sub(m, m), D_sub(p, p);

    for (int i = 0; i < m; ++i)
        for (int j = 0; j < m; ++j)
            F_sub(i, j) = F[unassigned_fac[i] * N + unassigned_fac[j]];

    for (int i = 0; i < p; ++i)
        for (int j = 0; j < p; ++j)
            D_sub(i, j) = D[unassigned_loc[i] * N + unassigned_loc[j]];

    //----- Cross-term matrix -----
    Eigen::MatrixXd C_cross(m, p);

    for (int i_idx = 0; i_idx < m; ++i_idx)
    {
        int i = unassigned_fac[i_idx];

        for (int k_idx = 0; k_idx < p; ++k_idx)
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

            C_cross(i_idx, k_idx) = cross;
        }
    }

    //----- Asymmetry correction -----
    double asym_correction = compute_asym_correction(F_sub, D_sub, m, p);

    //----- Compute bound -----
    double remaining;

    if (m == p && m > 2)
    {
        double ub_target = (double)(ub - fixed_cost);
        remaining = compute_evb3(F_sub, D_sub, C_cross, asym_correction, m, ub_target);
    }
    else
        remaining = compute_evb_rect(F_sub, D_sub, C_cross, asym_correction, m, p);

    longint remaining_lb = (longint) std::floor(remaining - 1e-9);

    return fixed_cost + remaining_lb;
}
