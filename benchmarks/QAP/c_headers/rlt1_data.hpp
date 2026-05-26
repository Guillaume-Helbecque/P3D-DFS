#ifndef __RLT1_DATA__
#define __RLT1_DATA__

#include "utils.hpp"

// Non-owning view over external working buffers. The caller (bound_RLT1) owns the
// vectors via a static pool; this class only references them and provides the
// dual-ascent methods. No default/copy/move constructors — references must be bound
// at construction and cannot be rebound.
class RLT1_Data
{
    private:

        std::vector<double>& costs;   // 4D cost array (m^4 entries) — quadratic level
        std::vector<double>& leader;  // 2D cost array (m^2 entries) — linear level
        int size;                     // m (remaining subproblem dimension)

    public:

        RLT1_Data (std::vector<double>& costs0, std::vector<double>& leader0, int N)
            : costs(costs0), leader(leader0), size(N) {}

        ~ RLT1_Data () = default;

        RLT1_Data (const RLT1_Data&) = delete;
        RLT1_Data& operator= (const RLT1_Data&) = delete;

        const std::vector<double>& get_costs () const { return costs; }
        std::vector<double>& get_costs () { return costs; }
        const std::vector<double>& get_leader () const { return leader; }
        std::vector<double>& get_leader () { return leader; }
        int get_size () const { return size; }

        void distributeLeader ();
        void halveComplementary ();
};

#endif
