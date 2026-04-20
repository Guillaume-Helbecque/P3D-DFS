#include "../c_headers/bound_glb.hpp"
#include "../c_headers/objective.hpp"


static inline bool ckmin(longint &a, const longint &b)
{
    return b < a ? (a = b, true) : false;
}


longint Hungarian_GLB(const std::vector<longint>& L, int n, int N)
{
    const longint INF2 = INF / 2;

    std::vector<int> job(N + 1, -1);
    std::vector<longint> yw(n, 0), yj(N + 1, 0);

    std::vector<longint> min_to(N + 1);
    std::vector<int> prv(N + 1);
    std::vector<bool> in_Z(N + 1);

    for (int w_cur = 0; w_cur < n; ++w_cur)
    {
        int j_cur = N;
        job[j_cur] = w_cur;

        std::fill(min_to.begin(), min_to.end(), INF2);
        std::fill(prv.begin(), prv.end(), -1);
        std::fill(in_Z.begin(), in_Z.end(), false);

        while (job[j_cur] != -1)
        {
            in_Z[j_cur] = true;
            int w = job[j_cur];
            longint delta = INF2;
            int j_next = 0;

            const longint* row = L.data() + w * N;

            for (int j = 0; j < N; ++j)
            {
                if (!in_Z[j])
                {
                    longint cur_cost = row[j] - yw[w] - yj[j];
                    if (ckmin(min_to[j], cur_cost))
                        prv[j] = j_cur;
                    if (ckmin(delta, min_to[j]))
                        j_next = j;
                }
            }

            for (int j = 0; j <= N; ++j)
            {
                if (in_Z[j])
                {
                    yw[job[j]] += delta;
                    yj[j] -= delta;
                }
                else
                {
                    min_to[j] -= delta;
                }
            }

            j_cur = j_next;
        }

        for (int j; j_cur != N; j_cur = j)
        {
            j = prv[j_cur];
            job[j_cur] = job[j];
        }
    }

    longint total_cost = 0;
    for (int j = 0; j < N; ++j)
        if (job[j] != -1)
            total_cost += L[job[j] * N + j];

    return total_cost;
}


longint bound_GLB(const vector<int>& mapping,
                  const vector<bool>& available,
                  int depth,
                  const vector<int>& F,
                  const vector<int>& D,
                  int n, int N)
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

    //----- Dimensions of the reduced problem -----
    int u = (int) unassigned_fac.size();
    int r = (int) unassigned_loc.size();

    //----- Precompute sorted distances from each available location to other available locations -----
    vector<vector<int>> sortedDist(r);

    for (int k_idx = 0; k_idx < r; ++k_idx)
    {
        int k = unassigned_loc[k_idx];

        sortedDist[k_idx].reserve(r - 1);
        for (int l_idx = 0; l_idx < r; ++l_idx)
        {
            if (l_idx == k_idx) continue;
            sortedDist[k_idx].push_back(D[k * N + unassigned_loc[l_idx]]);
        }

        sort(sortedDist[k_idx].begin(), sortedDist[k_idx].end());
    }

    //----- Build LAP cost matrix L (u x r) -----
    vector<longint> L(u * r, 0);

    for (int i_idx = 0; i_idx < u; ++i_idx)
    {
        int i = unassigned_fac[i_idx];

        // Extract flows from i to other unassigned facilities, sorted descending
        vector<int> flows;
        flows.reserve(u - 1);
        for (int j_idx = 0; j_idx < u; ++j_idx)
        {
            int j = unassigned_fac[j_idx];
            if (i == j) continue;
            flows.push_back(F[i * N + j]);
        }
        sort(flows.begin(), flows.end(), greater<int>());

        // Compute L[i_idx, k_idx] for each location k
        for (int k_idx = 0; k_idx < r; ++k_idx)
        {
            int k = unassigned_loc[k_idx];
            longint cost = 0;

            // Unassigned-unassigned part: GLB pairing (largest flows * smallest distances)
            int pairs = min((int) flows.size(), (int) sortedDist[k_idx].size());
            for (int t = 0; t < pairs; ++t)
                cost += (longint) flows[t] * sortedDist[k_idx][t];

            // Assigned-unassigned interactions (both directions)
            for (int a_idx = 0; a_idx < (int) assigned_fac.size(); ++a_idx)
            {
                int a = assigned_fac[a_idx];
                int b = mapping[a];

                cost += (longint) F[i * N + a] * D[k * N + b];
                cost += (longint) F[a * N + i] * D[b * N + k];
            }

            L[i_idx * r + k_idx] = cost;
        }
    }

    //----- Fixed cost + Hungarian on LAP matrix -----
    longint fixed_cost = Objective(mapping, F, D, n, N);

    longint remaining_lb = Hungarian_GLB(L, u, r);

    return fixed_cost + remaining_lb;
}
