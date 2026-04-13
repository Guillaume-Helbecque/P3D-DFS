#ifndef __BOUND_GLB__
#define __BOUND_GLB__

// #include "utils.hpp"

// Wrapper C pour interop Chapel
#ifdef __cplusplus
extern "C" {
#endif

// #include <iostream>
// #include <cassert>
// #include <limits>
// #include <vector>
// #include <queue>
// #include <stack>
// #include <algorithm>
// #include <chrono>
// #include <fstream>
// #include <string>
// #include <sstream>
// #include <cmath>
// #include <functional>

// using namespace std;
// using longint = long long;
// const longint INF = std::numeric_limits<longint>::max();

long long bound_GLB_wrapper(
    int* mapping,
    int* available,
    int depth,
    int* F,
    int* D,
    int n,
    int N
);

#ifdef __cplusplus
}
#endif

#endif
