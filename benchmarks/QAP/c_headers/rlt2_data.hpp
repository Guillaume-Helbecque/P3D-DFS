#ifndef __RLT2_DATA__
#define __RLT2_DATA__

#include "utils.hpp"

// Non-owning view over external working buffers. The caller (bound_RLT2) owns the
// vectors via a static pool; this class only references them and provides the
// dual-ascent methods. No default/copy/move constructors — references must be bound
// at construction and cannot be rebound.
class RLT2_Data
{
    private:

        std::vector<double>& cubic;   // 6D cost array (m^6 entries) — cubic level
        std::vector<double>& costs;   // 4D cost array (m^4 entries) — quadratic level
        std::vector<double>& leader;  // 2D cost array (m^2 entries) — linear level
        int size;                     // m (remaining subproblem dimension)

    public:

        RLT2_Data (std::vector<double>& cubic0, std::vector<double>& costs0,
                   std::vector<double>& leader0, int N)
            : cubic(cubic0), costs(costs0), leader(leader0), size(N) {}

        ~ RLT2_Data () = default;

        RLT2_Data (const RLT2_Data&) = delete;
        RLT2_Data& operator= (const RLT2_Data&) = delete;

        const std::vector<double>& get_cubic () const { return cubic; }
        std::vector<double>& get_cubic () { return cubic; }
        const std::vector<double>& get_costs () const { return costs; }
        std::vector<double>& get_costs () { return costs; }
        const std::vector<double>& get_leader () const { return leader; }
        std::vector<double>& get_leader () { return leader; }
        int get_size () const { return size; }

        void distributeLeader ();
        void distributeQuadratic ();
        void halveComplementary ();
        void halveComplementaryCubic ();
};

#endif
