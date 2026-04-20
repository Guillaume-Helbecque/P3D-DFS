#include "../c_headers/hungarian.hpp"


static inline bool ckmin_d(double &a, const double &b)
{
    return b < a ? (a = b, true) : false;
}


// ====================================================================
// Double-precision variants: same algorithm with double costs
// ====================================================================

double Hungarian_RLT_d(double* C, int i0, int j0, int N)
{
    int w, j, w_cur, j_cur, j_next;
    const long long base_ij = (long long)idx4D(i0, j0, 0, 0, N);

    // Thread-local persistent workspace: avoids per-call malloc/free churn
    // (the parallel cubic Hungarian can call this millions of times per B&B node).
    // vector<char> instead of vector<bool> for faster random access (no bit-packing).
    thread_local static vector<int>    job;
    thread_local static vector<double> yw, yj, min_to;
    thread_local static vector<int>    prv;
    thread_local static vector<char>   in_Z;

    const int Np1 = N + 1;
    if ((int)job.size() < Np1) {
        job.resize(Np1);
        yw.resize(Np1);
        yj.resize(Np1);
        min_to.resize(Np1);
        prv.resize(Np1);
        in_Z.resize(Np1);
    }

    // Reset workspace for this call
    for (int a = 0; a < Np1; ++a) {
        job[a] = -1;
        yw[a]  = 0.0;
        yj[a]  = 0.0;
    }

    for (w_cur = 0; w_cur < N; ++w_cur)
    {
        j_cur = N;
        job[j_cur] = w_cur;

        for (int a = 0; a < Np1; ++a) {
            min_to[a] = INF_D;
            prv[a]    = -1;
            in_Z[a]   = 0;
        }

        while (job[j_cur] != -1)
        {
            in_Z[j_cur] = 1;
            w = job[j_cur];
            double delta = INF_D;
            j_next = 0;

            double* row = C + base_ij + (long long)w * N;

            for (j = 0; j < N; ++j)
            {
                if (!in_Z[j])
                {
                    double cur_cost = row[j] - yw[w] - yj[j];
                    if (ckmin_d(min_to[j], cur_cost))
                        prv[j] = j_cur;
                    if (ckmin_d(delta, min_to[j]))
                        j_next = j;
                }
            }

            for (j = 0; j <= N; ++j)
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

        for (; j_cur != N; j_cur = j)
        {
            j = prv[j_cur];
            job[j_cur] = job[j];
        }
    }

    double total_cost = 0.0;
    for (j = 0; j < N; ++j)
        if (job[j] != -1)
            total_cost += C[base_ij + (long long)job[j] * N + j];

    for (w = 0; w < N; ++w)
    {
        double* row = C + base_ij + (long long)w * N;
        for (j = 0; j < N; ++j)
            if (row[j] < INF_D)
                row[j] = row[j] - yw[w] - yj[j];
    }

    return total_cost;
}


double Hungarian_RLT_assign_d(double* C, int i0, int j0, int N, vector<int>& assign_out)
{
    int w, j, w_cur, j_cur, j_next;
    const long long base_ij = (long long)idx4D(i0, j0, 0, 0, N);

    vector<int> job(N + 1, -1);
    vector<double> yw(N, 0.0), yj(N + 1, 0.0);
    vector<double> min_to(N + 1);
    vector<int> prv(N + 1);
    vector<bool> in_Z(N + 1);

    for (w_cur = 0; w_cur < N; ++w_cur)
    {
        j_cur = N;
        job[j_cur] = w_cur;

        std::fill(min_to.begin(), min_to.end(), INF_D);
        std::fill(prv.begin(), prv.end(), -1);
        std::fill(in_Z.begin(), in_Z.end(), false);

        while (job[j_cur] != -1)
        {
            in_Z[j_cur] = true;
            w = job[j_cur];
            double delta = INF_D;
            j_next = 0;

            double* row = C + base_ij + (long long)w * N;

            for (j = 0; j < N; ++j)
            {
                if (!in_Z[j])
                {
                    double cur_cost = row[j] - yw[w] - yj[j];
                    if (ckmin_d(min_to[j], cur_cost))
                        prv[j] = j_cur;
                    if (ckmin_d(delta, min_to[j]))
                        j_next = j;
                }
            }

            for (j = 0; j <= N; ++j)
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

        for (; j_cur != N; j_cur = j)
        {
            j = prv[j_cur];
            job[j_cur] = job[j];
        }
    }

    double total_cost = 0.0;
    for (j = 0; j < N; ++j)
        if (job[j] != -1)
            total_cost += C[base_ij + (long long)job[j] * N + j];

    assign_out.resize(N);
    for (j = 0; j < N; ++j)
        if (job[j] >= 0 && job[j] < N)
            assign_out[job[j]] = j;

    for (w = 0; w < N; ++w)
    {
        double* row = C + base_ij + (long long)w * N;
        for (j = 0; j < N; ++j)
            if (row[j] < INF_D)
                row[j] = row[j] - yw[w] - yj[j];
    }

    return total_cost;
}
