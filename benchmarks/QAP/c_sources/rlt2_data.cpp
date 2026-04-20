#include "../c_headers/rlt2_data.hpp"


void RLT2_Data::distributeLeader ()
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


void RLT2_Data::distributeQuadratic ()
{
    std::vector<double>& Cu = this->cubic;
    std::vector<double>& C  = this->costs;
    const int N = this->size;

    if (N <= 2) return;

    const double inv = 1.0 / (double)(N - 2);

    // Each (i, j, k, n) writes to disjoint Cu[i,j,k,n,*,*] and its own C[i,j,k,n] — safe.
    #pragma omp parallel for collapse(4) schedule(static) if(N >= 8)
    for (int i = 0; i < N; ++i)
    {
        for (int j = 0; j < N; ++j)
        {
            for (int k = 0; k < N; ++k)
            {
                for (int n = 0; n < N; ++n)
                {
                    if (k == i || n == j) continue;

                    long long idx_quad = idx4D(i, j, k, n, N);
                    double quad_cost = C[idx_quad];
                    C[idx_quad] = 0.0;

                    if (quad_cost == 0.0) continue;

                    // Exact equal split: each of the (N-2)^2 valid cells
                    // Cu[i,j,k,n,p,q] with p not in {i,k} and q not in {j,n}
                    // receives (quad_cost / (N-2)). The sum over each row
                    // (fixed p, q varying) is exactly quad_cost, and the total
                    // added to the Cu slab is (N-2) * quad_cost.
                    const double val = quad_cost * inv;

                    for (int p = 0; p < N; ++p)
                    {
                        if (p == i || p == k) continue;

                        long long base = idx6D(i, j, k, n, p, 0, N);
                        for (int q = 0; q < N; ++q)
                        {
                            if (q != j && q != n)
                                Cu[base + q] += val;
                        }
                    }
                }
            }
        }
    }
}


void RLT2_Data::halveComplementary ()
{
    std::vector<double>& C = this->costs;
    const int N = this->size;

    // Each (i < k, l != j) pair is processed once and writes to two disjoint cells
    // (C[i,j,k,l] and C[k,l,i,j]) that no other (i', j') thread touches.
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
                        // With doubles, no rounding, no asymmetry.
                        double half = (C[idx4D(i, j, k, l, N)] + C[idx4D(k, l, i, j, N)]) * 0.5;
                        C[idx4D(i, j, k, l, N)] = half;
                        C[idx4D(k, l, i, j, N)] = half;
                    }
                }
            }
        }
    }
}


void RLT2_Data::halveComplementaryCubic ()
{
    std::vector<double>& D = this->cubic;
    const int N = this->size;

    if (N <= 2) return;

    const long long N2 = (long long)N * N;
    const long long N4 = N2 * N2;

    const double inv6 = 1.0 / 6.0;

    // Enumerate sorted triples for balanced parallelization
    struct Triple { int i, k, p; };
    std::vector<Triple> triples;
    triples.reserve(N * (N - 1) * (N - 2) / 6);
    for (int ii = 0; ii < N - 2; ++ii)
        for (int kk = ii + 1; kk < N - 1; ++kk)
            for (int pp = kk + 1; pp < N; ++pp)
                triples.push_back({ii, kk, pp});

    const int nt = (int)triples.size();

    // Each sorted triple (i<k<p) × (j,n,q distinct) uniquely identifies 6 permutation
    // positions. Different tuples touch disjoint 6-element groups — safe to parallelize.
    #pragma omp parallel for schedule(static) if(nt >= 8)
    for (int t = 0; t < nt; ++t)
    {
        const int i = triples[t].i;
        const int k = triples[t].k;
        const int p = triples[t].p;

        for (int j = 0; j < N; ++j)
        {
            const long long ij    = (long long)i * N + j;
            const long long ij_N4 = ij * N4;
            const long long ij_N2 = ij * N2;

            for (int n = 0; n < N; ++n)
            {
                if (n == j) continue;

                const long long kn    = (long long)k * N + n;
                const long long kn_N4 = kn * N4;
                const long long kn_N2 = kn * N2;

                for (int q = 0; q < N; ++q)
                {
                    if (q == j || q == n) continue;

                    const long long pq    = (long long)p * N + q;
                    const long long pq_N4 = pq * N4;
                    const long long pq_N2 = pq * N2;

                    const long long i1 = ij_N4 + kn_N2 + pq;
                    const long long i2 = ij_N4 + pq_N2 + kn;
                    const long long i3 = kn_N4 + ij_N2 + pq;
                    const long long i4 = kn_N4 + pq_N2 + ij;
                    const long long i5 = pq_N4 + ij_N2 + kn;
                    const long long i6 = pq_N4 + kn_N2 + ij;

                    // Exact symmetric sixth: all 6 cells get sum/6 (no rounding, no asymmetry)
                    const double s   = D[i1] + D[i2] + D[i3] + D[i4] + D[i5] + D[i6];
                    const double avg = s * inv6;

                    D[i1] = avg;
                    D[i2] = avg;
                    D[i3] = avg;
                    D[i4] = avg;
                    D[i5] = avg;
                    D[i6] = avg;
                }
            }
        }
    }
}
