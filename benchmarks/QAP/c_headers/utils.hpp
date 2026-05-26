#ifndef __UTILS__
    #define __UTILS__

    #include <cassert>
    #include <limits>
    #include <vector>
    #include <algorithm>
    #include <cmath>

    using namespace std;
    using longint = long long;

    const longint INF   = std::numeric_limits<longint>::max();
    const double  INF_D = 1e18;  // double-precision sentinel threshold (used by RLT / Hungarian)

#ifdef __CUDACC__
    __host__ __device__
#endif
    // Returns long long. The horner-style evaluation with a long long cast at
    // the start prevents intermediate overflow for n > ~215. For typical QAP
    // instances (n <= ~60) the result still fits in int; call sites that need
    // int can cast explicitly. Matches the idx6D style below.
    inline long long idx4D(int i, int j, int k, int l, int n)
    {
        return (((long long)i * n + j) * n + k) * n + l;
    }

#ifdef __CUDACC__
    __host__ __device__
#endif
    inline long long idx6D(int i, int j, int k, int n, int p, int q, int m)
    {
        return (((((long long)i * m + j) * m + k) * m + n) * m + p) * m + q;
    }

    // RLT warm-start data: reduced matrices from parent node (shared by RLT1 and RLT2).
    // Uses double precision to avoid the systematic +1 asymmetry bias of integer
    // halving, which prevents the iterative Hahn RLT method from converging to
    // the true LP optimum. Accumulates across the B&B tree without lossy floor
    // conversions at each node.
    struct RLT_WarmData
    {
        vector<double> leader;  // parent's reduced leader (m^2)
        vector<double> costs;   // parent's reduced quadratic costs (m^4)
        vector<double> cubic;   // parent's reduced cubic costs (m^6)
        vector<int> uf;         // parent's unassigned facilities
        vector<int> al;         // parent's available locations
        int m;                  // parent's subproblem size
        double parent_bound;    // parent's computed bound (fixed_cost + R'), doubled space
    };

#endif
