#ifndef __EVB_BOUND__
#define __EVB_BOUND__

#include "utils.hpp"
#include <Eigen/Dense>

// Double-precision Hungarian algorithm for min-cost assignment.
double hungarian_double(const Eigen::MatrixXd& cost, int n, std::vector<int>& assignment);

// EVB3: iterative eigenvalue bound with subgradient optimization (square case).
double compute_evb3(const Eigen::MatrixXd& F_sub, const Eigen::MatrixXd& D_sub,
                    const Eigen::MatrixXd& C_cross, double asym_correction, int m,
                    double ub_target = 1e30);

// Asymmetry correction: -sum_k sigma_k(F_a) * sigma_k(D_a).
//
// Two overloads:
//   * Original: computes both F-side (F_a = 0.5*(F-F^T), sing(F_a)) and
//     D-side (D_a = 0.5*(D-D^T), sing(D_a)) from scratch. Used when no
//     cache is available (e.g. EVB free-function, GPU CPU fallback).
//   * Cached: reuses precomputed F-side data (fnorm_Fa + sing(F_a)) from a
//     QPBEigenCache built once per parent. Skips the F-side build + SVD on
//     every sibling. Only the D-side is rebuilt per call (D varies across
//     siblings). Used by the CPU QPB hot path (node.cpp / main_mpi.cpp).
double compute_asym_correction(const Eigen::MatrixXd& F_sub, const Eigen::MatrixXd& D_sub,
                               int m, int p);
double compute_asym_correction(double cached_fnormFa,
                               const Eigen::VectorXd& cached_singFa,
                               const Eigen::MatrixXd& D_sub, int p);

// Basic eigenvalue bound for rectangular sub-problems (m < p).
double compute_evb_rect(const Eigen::MatrixXd& F_sub, const Eigen::MatrixXd& D_sub,
                        const Eigen::MatrixXd& C_cross, double asym_correction, int m, int p);

// EVB lower bound (free-function interface)
longint bound_EVB(const std::vector<int>& mapping,
                  const std::vector<bool>& available,
                  int depth,
                  const std::vector<int>& F,
                  const std::vector<int>& D,
                  int n, int N,
                  longint ub);

#endif
