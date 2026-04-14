#ifndef __HUNGARIAN__
    #define __HUNGARIAN__

    #include "utils.hpp"

    // Double-precision Hungarian for RLT1/RLT2 submatrix and leader reductions.
    double Hungarian_RLT_d(double*, int, int, int);
    double Hungarian_RLT_assign_d(double*, int, int, int, vector<int>&);

#endif
