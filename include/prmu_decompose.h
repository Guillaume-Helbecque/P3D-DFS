#ifndef PRMU_DECOMPOSE_H
#define PRMU_DECOMPOSE_H

#include <vector>
#include <chrono>
#include <thread>


#include <base_decompose.h>
#include <prmu_subproblem.h>

class DecomposePerm : public DecomposeBase<PermutationSubproblem>
{
public:
    std::vector<std::unique_ptr<PermutationSubproblem>> operator()(PermutationSubproblem& n){
        std::vector<std::unique_ptr<PermutationSubproblem>>children;

       //reverse (to get lexicographic DFS)
       for (int j = n.limit2 - 1; j > n.limit1; j--) {
           //generates j^th child of parent node n
           //...maybe just copy construct and modify child here (feels weird to have branching logic hidden in ctor...)
           auto tmp = std::make_unique<PermutationSubproblem>(n,j);

           std::this_thread::sleep_for(std::chrono::nanoseconds(100));

           children.push_back(std::move(tmp));
       }

       return children;
    };
};

#endif
