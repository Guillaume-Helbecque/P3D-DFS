#include "../c_headers/bound_iglb.hpp"
#include "../c_headers/bound_glb.hpp"
#include "../c_headers/objective.hpp"


static vector<longint> assemble_LAP_IGLB (const vector<int>& mapping, const vector<bool>& av,
                                           int depth,
                                           const vector<int>& F, const vector<int>& D,
                                           int n, int N)
{
    int dp = depth;

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
        if (av[k])
            unassigned_loc.push_back(k);
    }

    //----- Dimensions of the reduced problem -----
    int u = (int) unassigned_fac.size();
    int r = (int) unassigned_loc.size();

    vector<longint> L(u * r, 0);

    //----- Precompute AU[j_idx][l_idx]: assigned-unassigned cost for each (j, l) pair -----
    vector<longint> AU(u * r, 0);

    for (int j_idx = 0; j_idx < u; ++j_idx)
    {
        int j = unassigned_fac[j_idx];

        for (int l_idx = 0; l_idx < r; ++l_idx)
        {
            int l = unassigned_loc[l_idx];
            longint au = 0;

            for (int a_idx = 0; a_idx < dp; ++a_idx)
            {
                int a = assigned_fac[a_idx];
                int b = mapping[a];

                au += (longint) F[j * N + a] * (longint) D[l * N + b];
                au += (longint) F[a * N + j] * (longint) D[b * N + l];
            }

            AU[j_idx * r + l_idx] = au;
        }
    }

    //----- Build main LAP matrix L -----
    int su = u - 1;
    int sr = r - 1;

    // Pre-allocate secondary LAP matrix once (reused for each (i, k) pair)
    vector<longint> S(su * sr, 0);

    for (int i_idx = 0; i_idx < u; ++i_idx)
    {
        int i = unassigned_fac[i_idx];

        for (int k_idx = 0; k_idx < r; ++k_idx)
        {
            int k = unassigned_loc[k_idx];

            // fraction of facility i's own AU cost
            longint cost = AU[i_idx * r + k_idx] / u;

            // unassigned-unassigned part: secondary LAP with AU-enhanced costs
            if (su > 0 && sr > 0)
            {
                int row = 0;
                for (int j_idx = 0; j_idx < u; ++j_idx)
                {
                    if (j_idx == i_idx) continue;
                    int j = unassigned_fac[j_idx];

                    int col = 0;
                    for (int l_idx = 0; l_idx < r; ++l_idx)
                    {
                        if (l_idx == k_idx) continue;
                        int l = unassigned_loc[l_idx];

                        S[row * sr + col] = (longint) F[i * N + j] * (longint) D[k * N + l]
                                          + AU[j_idx * r + l_idx] / u;
                        col++;
                    }
                    row++;
                }

                cost += Hungarian_GLB(S, su, sr);
            }

            L[i_idx * r + k_idx] = cost;
        }
    }

    return L;
}


longint bound_IGLB (const vector<int>& mapping, const vector<bool>& available, int depth,
                    const vector<int>& F, const vector<int>& D, int n, int N)
{
    int dp = depth;

    vector<longint> L = assemble_LAP_IGLB(mapping, available, depth, F, D, n, N);

    longint fixed_cost = Objective(mapping, F, D, n, N);

    longint remaining_lb = Hungarian_GLB(L, n - dp, N - dp);

    return fixed_cost + remaining_lb;
}
