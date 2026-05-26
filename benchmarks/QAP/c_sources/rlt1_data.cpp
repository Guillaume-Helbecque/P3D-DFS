#include "../c_headers/rlt1_data.hpp"


void RLT1_Data::distributeLeader ()
{
    std::vector<double>& C = this->costs;
    std::vector<double>& L = this->leader;
    const int N = this->size;

    if (N == 1)
    {
        // Only the single cell (i=j=0) exists. We cannot distribute L[0] anywhere
        // (no valid (k,l) with k!=i, l!=j), so leave L[0] intact so that the
        // subsequent Hungarian-on-L step extracts its full value into lb. We still
        // zero C[0,0,0,0] to remove the double-count with L[0] (since the diagonal
        // cell C[i,j,i,j] is initialized to 2*F[i,i]*D[j,j], which is already
        // folded into L[i,j] at initialization).
        C[0] = 0.0;
        return;
    }

    const double inv = 1.0 / (double)(N - 1);

    // Each (i, j) writes to disjoint C[i,j,*,*] and its own L[i,j] — safe to parallelize.
    #pragma omp parallel for collapse(2) schedule(static) if(N >= 8)
    for (int i = 0; i < N; ++i)
    {
        for (int j = 0; j < N; ++j)
        {
            double leader_cost = L[i*N + j];

            C[idx4D(i, j, i, j, N)] = 0.0;
            L[i*N + j] = 0.0;

            if (leader_cost == 0.0)
                continue;

            // Exact equal split: each of the (N-1)^2 off-diagonal cells C[i,j,k,l]
            // with k != i and l != j receives (leader_cost / (N-1)). The sum over
            // each row (fixed k, l varying) is therefore exactly leader_cost, and the
            // total added to the C slab is (N-1) * leader_cost.
            const double val = leader_cost * inv;

            for (int k = 0; k < N; ++k)
            {
                if (k == i) continue;
                for (int l = 0; l < N; ++l)
                {
                    if (l != j)
                        C[idx4D(i, j, k, l, N)] += val;
                }
            }
        }
    }
}


void RLT1_Data::halveComplementary ()
{
    std::vector<double>& C = this->costs;
    const int N = this->size;

    // Each (i < k, l != j) pair is processed once and writes to two disjoint cells.
    // The "k starts at i" loop gives k > i due to the (k != i) test, which ensures
    // each pair {(i,j,k,l), (k,l,i,j)} is handled exactly once across all iterations.
    #pragma omp parallel for collapse(2) schedule(static) if(N >= 8)
    for (int i = 0; i < N; ++i)
    {
        for (int j = 0; j < N; ++j)
        {
            for (int k = i; k < N; ++k)
            {
                for (int l = 0; l < N; ++l)
                {
                    if ((k != i) && (l != j))
                    {
                        // Exact symmetric halving: both positions get the same value.
                        // With doubles, no rounding, no +1 asymmetry bias.
                        double half = (C[idx4D(i, j, k, l, N)] + C[idx4D(k, l, i, j, N)]) * 0.5;
                        C[idx4D(i, j, k, l, N)] = half;
                        C[idx4D(k, l, i, j, N)] = half;
                    }
                }
            }
        }
    }
}
