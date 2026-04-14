#include "../c_headers/c_wrappers.h"

#include "../c_headers/bound_glb.hpp"

longint bound_GLB_wrapper(int* mapping, int* available, int depth, int* F,
  int* D, int n, int N)
{
    // Conversion vers std::vector
    std::vector<int> v_mapping(mapping, mapping + n);
    std::vector<bool> v_available(N,true);
    for (int i = 0; i < N; i++) {
      v_available[i] = (available[i] == 0) ? false : true;
    }
    std::vector<int> v_F(F, F + N * N);
    std::vector<int> v_D(D, D + N * N);

    return bound_GLB(v_mapping, v_available, depth, v_F, v_D, n, N);
}
