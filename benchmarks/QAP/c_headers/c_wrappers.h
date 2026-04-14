#ifndef __C_WRAPPERS__
#define __C_WRAPPERS__

#ifdef __cplusplus
extern "C" {
#endif

long long bound_GLB_wrapper(int* mapping, int* available, int depth, int* F,
  int* D, int n, int N);

#ifdef __cplusplus
}
#endif

#endif
