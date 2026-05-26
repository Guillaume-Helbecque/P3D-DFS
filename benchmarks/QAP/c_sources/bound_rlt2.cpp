#include "../c_headers/bound_rlt2.hpp"
#include "../c_headers/rlt2_data.hpp"
#include "../c_headers/hungarian.hpp"
#include "../c_headers/objective.hpp"

#include <cmath>


longint bound_RLT2(const std::vector<int>& mapping,
                       const std::vector<bool>& available,
                       int depth,
                       const std::vector<int>& F,
                       const std::vector<int>& D,
                       int n, int N,
                       int rlt2_itmax, double rlt2_tol,
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
    long long m4 = (long long)m2 * m2;
    long long m6 = m4 * (long long)m2;

    // Persistent working buffers (function-scope thread-local statics, reused across
    // calls). `thread_local` is required so that external callers running the
    // bounding operator from multiple worker threads (e.g., Chapel tasks in the
    // P3D-DFS integration) each get their own pool, avoiding the data race that
    // would otherwise corrupt the cost/leader/cubic matrices. The CPU-standalone
    // B&B is single-threaded at this level so only one pool is ever populated
    // there, and the OpenMP regions below still parallelize safely because they
    // only read and write to disjoint cells of the pool owned by the calling
    // thread. resize() only zero-initializes cells that are being newly added
    // when the buffer grows; the initialization phase below then overwrites
    // every used cell, so repeated same-or-smaller-m calls pay zero allocation
    // or zero-init cost. The cubic buffer dominates (m^6 doubles), so reusing
    // it across nodes is the main win on larger instances.
    thread_local static std::vector<double> costs_pool;
    thread_local static std::vector<double> leader_pool;
    thread_local static std::vector<double> cubic_pool;
    costs_pool.resize((size_t)m4);
    leader_pool.resize((size_t)m2);
    // cubic is (re)sized below, inside the `if (m > 2)` guard, to keep RLT2 with
    // m <= 2 from touching the cubic pool at all.
    std::vector<double>& costs  = costs_pool;
    std::vector<double>& leader = leader_pool;

    // ---- Determine warm-start feasibility (moved up so we can skip fixed_cost
    //      computation on the warm path — Fix #10). ----
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
            {
                int ci = 0;
                for (int x = 0; x < pm; ++x)
                    if (x != pi) fac_map[ci++] = x;
            }
            {
                int cj = 0;
                for (int x = 0; x < pm; ++x)
                    if (x != pj) loc_map[cj++] = x;
            }
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

    double lb;

    if (warm_ok)
    {
        // ---- Warm-start: REPLACE costs with parent's residuals ----
        const int pm = warm->m;

        // lb starts at parent's accumulated bound + branching pair's residual leader
        lb = warm->parent_bound + warm->leader[pi * pm + pj];

        // Set leader from parent's residual leader + branching pair's quadratic
        for (int ck = 0; ck < m; ++ck)
        {
            int pk = fac_map[ck];
            for (int cl = 0; cl < m; ++cl)
            {
                int pl = loc_map[cl];
                leader[ck*m + cl] = warm->leader[pk*pm + pl];

                double c1 = warm->costs[idx4D(pi, pj, pk, pl, pm)];
                double c2 = warm->costs[idx4D(pk, pl, pi, pj, pm)];
                if (c1 < INF_D) leader[ck*m + cl] += c1;
                if (c2 < INF_D) leader[ck*m + cl] += c2;
            }
        }

        // Set costs from parent's residual quadratic (with infeasibility markers)
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
                        long long child_idx = idx4D(ck, cl, cp, cq, m);

                        if ((cp == ck) ^ (cq == cl))
                        {
                            costs[child_idx] = INF_D;
                        }
                        else
                        {
                            double pc = warm->costs[idx4D(pk, pl, pp, pq_idx, pm)];
                            costs[child_idx] = (pc < INF_D) ? pc : INF_D;
                        }
                    }
                }
            }
        }

        // Add parent's cubic costs involving branching pair to child costs
        if (pm > 2 && !warm->cubic.empty())
        {
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
                            long long child_idx = idx4D(ck, cl, cp, cq, m);
                            if (costs[child_idx] >= INF_D) continue;

                            double d1 = warm->cubic[idx6D(pi, pj, pk, pl, pp, pq_idx, pm)];
                            double d2 = warm->cubic[idx6D(pk, pl, pi, pj, pp, pq_idx, pm)];
                            double d3 = warm->cubic[idx6D(pk, pl, pp, pq_idx, pi, pj, pm)];

                            if (d1 < INF_D) costs[child_idx] += d1;
                            if (d2 < INF_D) costs[child_idx] += d2;
                            if (d3 < INF_D) costs[child_idx] += d3;
                        }
                    }
                }
            }
        }
    }
    else
    {
        // ---- No warm-start: compute fresh costs ----
        lb = 2.0 * (double)fixed_cost;

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

                // Leader = diagonal entry
                leader[i*m + j] = costs[idx4D(i, j, i, j, m)];

                // Add interaction costs with assigned pairs
                for (int a = 0; a < n; ++a)
                {
                    if (mapping[a] == -1) continue;
                    leader[i*m + j] += 2.0 * ((double)F[uf[i] * N + a] * (double)D[al[j] * N + mapping[a]]
                                            + (double)F[a * N + uf[i]] * (double)D[mapping[a] * N + al[j]]);
                }
            }
        }
    }

    // Build cubic cost matrix. Resize only if m > 2; smaller subproblems never touch
    // the cubic pool, so we keep it empty (and don't pay the pool's initial allocation
    // cost) until a large enough problem shows up.
    if (m > 2)
        cubic_pool.resize((size_t)m6);
    std::vector<double>& cubic = cubic_pool;

    if (m > 2)
    {
        if (warm_ok && warm->m > 2 && !warm->cubic.empty())
        {
            // Copy parent's cubic residuals (excluding branching pair)
            const int pm = warm->m;
            for (int ck = 0; ck < m; ++ck)
            {
                int pk = fac_map[ck];
                for (int cl = 0; cl < m; ++cl)
                {
                    int pl = loc_map[cl];
                    for (int cp = 0; cp < m; ++cp)
                    {
                        int pp = fac_map[cp];
                        for (int cq = 0; cq < m; ++cq)
                        {
                            int pq_idx = loc_map[cq];
                            long long child_base = idx6D(ck, cl, cp, cq, 0, 0, m);
                            long long parent_base = idx6D(pk, pl, pp, pq_idx, 0, 0, pm);
                            for (int cr = 0; cr < m; ++cr)
                            {
                                int pr = fac_map[cr];
                                for (int cs = 0; cs < m; ++cs)
                                {
                                    int ps_idx = loc_map[cs];
                                    cubic[child_base + cr * m + cs] =
                                        warm->cubic[parent_base + pr * pm + ps_idx];
                                }
                            }
                        }
                    }
                }
            }
        }
        else
        {
            // Standard initialization (zeros + inf)
            for (int i = 0; i < m; ++i)
            {
                for (int j = 0; j < m; ++j)
                {
                    for (int kk = 0; kk < m; ++kk)
                    {
                        for (int nn = 0; nn < m; ++nn)
                        {
                            long long base = idx6D(i, j, kk, nn, 0, 0, m);

                            if ((kk == i) ^ (nn == j))
                            {
                                std::fill(cubic.data() + base, cubic.data() + base + m*m, INF_D);
                            }
                            else
                            {
                                // Set every cell explicitly (INF_D or 0). The previous
                                // code relied on the cubic vector being pre-zeroed by
                                // its constructor; with the static pool, leftover
                                // reduced values from a prior call would otherwise
                                // remain in non-INF_D cells.
                                for (int p = 0; p < m; ++p)
                                {
                                    for (int q = 0; q < m; ++q)
                                    {
                                        if (((p == i) ^ (q == j)) || ((p == kk) ^ (q == nn)))
                                            cubic[base + p*m + q] = INF_D;
                                        else
                                            cubic[base + p*m + q] = 0.0;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Create RLT2_Data — non-owning view over the static pool buffers (costs, leader,
    // cubic are all references to cubic_pool/costs_pool/leader_pool above).
    RLT2_Data CM{cubic, costs, leader, m};

    std::vector<double>& Cu = CM.get_cubic();
    std::vector<double>& C  = CM.get_costs();
    std::vector<double>& L  = CM.get_leader();

    double incre;
    int it = 0;

    // Small positive epsilon: iteration stops if incre <= eps (no meaningful progress)
    const double incre_eps = 1e-9;

    while (it < rlt2_itmax && lb < 2.0 * (double)UB)
    {
        ++it;

        // Step 1a: distribute leader costs to quadratic level
        CM.distributeLeader();

        if (m > 2)
        {
            // Step 1b: distribute quadratic costs to cubic level
            CM.distributeQuadratic();

            // Symmetrize cubic costs (exact symmetric halving via doubles)
            CM.halveComplementaryCubic();

            // Step 2a: Hungarian on each sub-submatrix (cubic -> quadratic).
            // This is the hottest part of the iteration: O(m^4) Hungarian calls,
            // each operating on a disjoint (m x m) sub-submatrix block in Cu and
            // writing to its own cell in C[i,j,k,l]. No data races — parallelize
            // across all 4 dimensions for maximum throughput.
            #pragma omp parallel for collapse(4) schedule(static) if(m >= 8)
            for (int i = 0; i < m; ++i)
            {
                for (int j = 0; j < m; ++j)
                {
                    for (int k = 0; k < m; ++k)
                    {
                        for (int l = 0; l < m; ++l)
                        {
                            if (k == i || l == j) continue;

                            long long base = idx6D(i, j, k, l, 0, 0, m);
                            double c = Hungarian_RLT_d(Cu.data() + base, 0, 0, m);
                            C[idx4D(i, j, k, l, m)] += c;
                        }
                    }
                }
            }
        }

        // Symmetrize quadratic costs (exact symmetric halving via doubles)
        CM.halveComplementary();

        // Step 2b: Hungarian on each submatrix (quadratic -> linear). Each (i, j)
        // operates on its disjoint submatrix C[i,j,*,*] and writes to its own L[i,j].
        #pragma omp parallel for collapse(2) schedule(static) if(m >= 8)
        for (int i = 0; i < m; ++i)
        {
            for (int j = 0; j < m; ++j)
            {
                double c = Hungarian_RLT_d(C.data(), i, j, m);
                L[i*m + j] += c;
            }
        }

        // Step 3: Hungarian on leader (linear -> bound)
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

        // Progress-based convergence check
        if (rlt2_tol > 0.0 && UB > 0 && incre / (2.0 * (double)UB) < rlt2_tol)
            break;
    }

    // Output reduced matrices for warm-starting children (doubles directly).
    // For m <= 2 the cubic buffer was not resized or initialized for this call
    // (it may hold leftover data from a previous larger-m call in the static pool),
    // so we explicitly clear out->cubic rather than copying it. Children only read
    // out->cubic when the parent had m > 2, so the clear is semantically correct.
    if (out != nullptr)
    {
        out->leader       = L;
        out->costs        = C;
        if (m > 2)
            out->cubic    = Cu;
        else
            out->cubic.clear();
        out->uf           = uf;
        out->al           = al;
        out->m            = m;
        out->parent_bound = lb;
    }

    // Final bound: floor(lb / 2) for a valid integer lower bound
    return (longint)std::floor(lb * 0.5);
}
