#include "../c_headers/bound_rlt1.hpp"
#include "../c_headers/rlt1_data.hpp"
#include "../c_headers/hungarian.hpp"
#include "../c_headers/objective.hpp"

#include <cmath>


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
                   RLT_WarmData* out)
{
    const int dp = depth;

    // Build lists of unassigned facilities and available locations
    std::vector<int> uf;
    uf.reserve(n - dp);
    for (int f = 0; f < n; ++f)
        if (mapping[f] == -1)
            uf.push_back(f);

    std::vector<int> al;
    al.reserve(N - dp);
    for (int l = 0; l < N; ++l)
        if (available[l])
            al.push_back(l);

    const int m = (int)al.size();
    assert(m > 0 && "Error: Cannot bound problem of size 0.");

    int m2 = m * m;

    // Persistent working buffers (function-scope static, reused across calls).
    // Thread-safety: NOT safe for concurrent calls from multiple threads, since the
    // static buffers are shared. The current B&B architecture is single-threaded at
    // this level (OpenMP parallelizes INSIDE bound_RLT1, not around it), so this is
    // safe. resize() only zero-initializes cells that are being newly added when the
    // buffer grows; the initialization phase below then overwrites every used cell,
    // so repeated same-m calls pay zero allocation or zero-init cost.
    static std::vector<double> costs_pool;
    static std::vector<double> leader_pool;
    costs_pool.resize((size_t)m2 * m2);
    leader_pool.resize((size_t)m2);
    std::vector<double>& costs  = costs_pool;
    std::vector<double>& leader = leader_pool;

    // Check if warm-start from parent is available (moved up so we can skip
    // fixed_cost computation on the warm path — Fix #10).
    bool warm_ok = false;
    int pi = -1, pj = -1;
    std::vector<int> fac_map, loc_map;

    if (warm != nullptr && warm->m > 0)
    {
        const int pm = warm->m;
        const std::vector<int>& puf = warm->uf;
        const std::vector<int>& pal = warm->al;

        for (int x = 0; x < pm; ++x)
        {
            if (puf[x] == warm_branch_fac) pi = x;
            if (pal[x] == warm_branch_loc) pj = x;
        }

        if (pi >= 0 && pj >= 0)
        {
            warm_ok = true;
            fac_map.resize(m);
            loc_map.resize(m);
            int ci = 0;
            for (int x = 0; x < pm; ++x)
                if (x != pi) fac_map[ci++] = x;
            int cj = 0;
            for (int x = 0; x < pm; ++x)
                if (x != pj) loc_map[cj++] = x;
        }
    }

    // Fix #10: fixed_cost is only used as the starting lb in the non-warm path.
    // On the warm path we overwrite lb with (parent_bound + residual leader), so
    // the O(n^2) double loop would be wasted work. Skip it.
    longint fixed_cost = 0;
    if (!warm_ok)
    {
        for (int a = 0; a < n; ++a)
        {
            if (mapping[a] == -1) continue;
            for (int b = 0; b < n; ++b)
            {
                if (mapping[b] == -1) continue;
                fixed_cost += (longint)F[a * N + b] * D[mapping[a] * N + mapping[b]];
            }
        }
    }

    if (warm_ok)
    {
        const int pm = warm->m;

        // REPLACE initialization with parent's reduced matrices
        for (int ck = 0; ck < m; ++ck)
        {
            int pk = fac_map[ck];
            for (int cl = 0; cl < m; ++cl)
            {
                int pl = loc_map[cl];
                double val = warm->leader[pk * pm + pl];

                double c1 = warm->costs[idx4D(pi, pj, pk, pl, pm)];
                double c2 = warm->costs[idx4D(pk, pl, pi, pj, pm)];
                if (c1 < INF_D) val += c1;
                if (c2 < INF_D) val += c2;

                leader[ck * m + cl] = val;
            }
        }

        // Child's costs = parent's remaining reduced quadratic costs
        for (int ck = 0; ck < m; ++ck)
        {
            for (int cl = 0; cl < m; ++cl)
            {
                int pk = fac_map[ck];
                int pl = loc_map[cl];
                for (int cp = 0; cp < m; ++cp)
                {
                    int pp = fac_map[cp];
                    for (int cq = 0; cq < m; ++cq)
                    {
                        int pq_idx = loc_map[cq];
                        costs[idx4D(ck, cl, cp, cq, m)] = warm->costs[idx4D(pk, pl, pp, pq_idx, pm)];
                    }
                }
            }
        }
    }
    else
    {
        // Standard F/D-based initialization
        for (int i = 0; i < m; ++i)
        {
            for (int j = 0; j < m; ++j)
            {
                for (int k = 0; k < m; ++k)
                {
                    for (int l = 0; l < m; ++l)
                    {
                        if ((k == i) ^ (l == j))
                            costs[idx4D(i, j, k, l, m)] = INF_D;
                        else
                            costs[idx4D(i, j, k, l, m)] = 2.0 * (double)F[uf[i] * N + uf[k]] * (double)D[al[j] * N + al[l]];
                    }
                }

                leader[i*m + j] = costs[idx4D(i, j, i, j, m)];

                for (int a = 0; a < n; ++a)
                {
                    if (mapping[a] == -1) continue;
                    leader[i*m + j] += 2.0 * ((double)F[uf[i] * N + a] * (double)D[al[j] * N + mapping[a]]
                                            + (double)F[a * N + uf[i]] * (double)D[mapping[a] * N + al[j]]);
                }
            }
        }
    }

    // Create RLT1_Data and run iterations
    RLT1_Data CM{costs, leader, m};

    // When warm-starting, the child inherits the parent's accumulated bound
    // plus the branching entry's residual leader cost (maintaining the DP invariant).
    double lb = 2.0 * (double)fixed_cost;
    if (warm_ok)
    {
        const int pm = warm->m;
        lb = warm->parent_bound + warm->leader[pi * pm + pj];
    }

    std::vector<double>& C = CM.get_costs();
    std::vector<double>& L = CM.get_leader();

    double incre;
    int it = 0;

    const double incre_eps = 1e-9;

    while (it < rlt_itmax && lb < 2.0 * (double)UB)
    {
        ++it;

        CM.distributeLeader();
        CM.halveComplementary();

        // Hungarian on each submatrix (quadratic -> linear). Each (i, j) runs the
        // Hungarian on its own submatrix C[i,j,*,*] (disjoint memory blocks) and
        // writes to its own L[i,j] — safe to parallelize across threads.
        #pragma omp parallel for collapse(2) schedule(static) if(m >= 8)
        for (int i = 0; i < m; ++i)
        {
            for (int j = 0; j < m; ++j)
            {
                double c = Hungarian_RLT_d(C.data(), i, j, m);
                L[i*m + j] += c;
            }
        }

        // Hungarian on leader (linear -> bound)
        std::vector<int> hungarian_assign;
        incre = Hungarian_RLT_assign_d(L.data(), 0, 0, m, hungarian_assign);

        if (incre <= incre_eps)
            break;

        lb += incre;

        // Build candidate solution from Hungarian assignment
        std::vector<int> candidate = mapping;
        for (int ii = 0; ii < m; ++ii)
            candidate[uf[ii]] = al[hungarian_assign[ii]];

        longint candidate_cost = Objective(candidate, F, D, n, N);
        if (candidate_cost < UB)
        {
            UB = candidate_cost;
            opt_solution = candidate;
        }

        if (rlt_tol > 0.0 && UB > 0 && incre / (2.0 * (double)UB) < rlt_tol)
            break;
    }

    // Output reduced matrices for warm-starting children
    if (out != nullptr)
    {
        out->leader       = L;
        out->costs        = C;
        out->cubic.clear();
        out->uf           = uf;
        out->al           = al;
        out->m            = m;
        out->parent_bound = lb;
    }

    // Final bound: floor(lb / 2) for a valid integer lower bound
    return (longint)std::floor(lb * 0.5);
}
