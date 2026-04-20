#ifndef __UTILS__
    #define __UTILS__

    #include <iostream>
    #include <cassert>
    #include <limits>
    #include <vector>
    #include <queue>
    #include <stack>
    #include <algorithm>
    #include <chrono>
    #include <fstream>
    #include <string>
    #include <sstream>
    #include <cmath>
    #include <functional>

    using namespace std;
    using longint = long long;

    #define INST_PATH "../benchmark/"
    #define MAX_RLT1_ITMAX 100
    #define MAX_RLT2_ITMAX 200

    const longint INF    = std::numeric_limits<longint>::max();
    const int     INF_32 = std::numeric_limits<int>::max();
    const double  INF_D  = 1e18;  // double-precision sentinel threshold (used by RLT/NB/Hungarian)

    // CPU project: selects one of these as the primary B&B lower bound
    enum LowerBound
    {
        GLB,
        IGLB,
        EVB,
        QPB,
        RLT1,
        RLT2,
        NB,
    };

    // GPU project: selects one of these as the CPU fallback bound
    enum CpuBound
    {
        CPU_GLB,
        CPU_IGLB,
        CPU_EVB,
        CPU_QPB,
        CPU_RLT1,
        CPU_RLT2,
        CPU_NB,
    };

    enum Ordering
    {
        standard,
        reversed,
        alternate,
        prioritized,
    };

    struct Options
    {
        string inst;                   // mandatory
        Ordering orderFac  = prioritized;
        Ordering orderLoc  = prioritized;
        string ub          = "greedy";
        string solFile     = "";       // empty = no saving
        // CPU-specific: selects primary lower-bound operator
        LowerBound LB      = GLB;
        // GPU-specific: selects CPU fallback bound & GPU threshold
        CpuBound lb_cpu    = CPU_RLT1;
        int gpu_threshold  = 7;
        // QPB-specific parameters
        int qpb_maxFW      = 10;      // max Frank-Wolfe iterations
        double qpb_tol     = 1e-5;    // FW convergence tolerance
        // RLT1-specific parameters
        int rlt1_itmax     = 25;
        double rlt1_tol    = 1e-6;    // relative convergence tolerance
        // RLT2-specific parameters
        int rlt2_itmax     = 50;
        double rlt2_tol    = 1e-6;    // relative convergence tolerance
        // NB-specific parameters
        double nb_lambda   = 5.0e4;   // penalty weight for doubly-stochastic constraints
        int nb_itmax       = 50;      // max Newton-Bracket iterations
        int nb_itmaxAPGR   = 3000;    // max APGR iterations per NB step
        double nb_delta    = 0.01;    // absolute gap tolerance
        double nb_delta1   = 1e-5;    // relative gap tolerance
        int nb_verbose     = 0;       // NB debug output level (0=off, 1=per-node)
        bool nb_compSW     = true;    // NB complementarity constraints
        // MPI-specific parameters
        int init_tasks     = 1;       // minimum initial tasks per MPI process (CPU only)
        double sync_factor = -1.0;    // sync workload multiplier (in units of n-1)
                                      // -1 = auto (set by ParseArguments based on LB / project)
    };

#ifdef __CUDACC__
    __host__ __device__
#endif
    // Fix #5: returns long long. The horner-style evaluation with a long long cast at
    // the start prevents intermediate overflow for n > ~215. For typical QAP instances
    // (n <= ~60) the result still fits in int; call sites that need int can cast
    // explicitly. Matches the idx6D style below.
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

    // ---- Common utility functions ----
    vector<int> Arange(int);
    void LoadMatrices(vector<int>&, vector<int>&, int&, int&, const string&);
    void DisplayResults(const string, const vector<int>&, longint, double, double);
    void SaveSolution(const string, const vector<int>&, longint,
                      const vector<int>&, const vector<int>&, int, int);

    Ordering ParseOrdering(const string& name);
    string OrderingToString(Ordering);
    string GetFileName(const string& path);
    void EnsureExtension(string& path, const string& ext);

    // ---- Project-specific functions (defined in utils_cpu.cpp or utils_gpu.cpp) ----
    Options ParseArguments(int argc, char** argv, bool mpi = false);
    void DisplayInput(const Options, int n, int N, longint UB,
                      const char* gpu_name = nullptr, size_t gpu_mem_mb = 0,
                      int num_proc = -1);

    // overload operator << to display a 1D vector
    template <typename T>
    std::ostream& operator<<(std::ostream& os, const vector<T>& vec)
    {
        os << "[ ";
        for (size_t i = 0; i < vec.size(); ++i)
            os << vec[i] << " ";
        os << "]";
        return os;
    }

    // overload operator << to display a 2D matrix
    template <typename T>
    std::ostream& operator<<(std::ostream& os, const vector<vector<T>>& matrix)
    {
        for (const auto &row : matrix)
            os << row << "\n";

        return os;
    }

#endif
