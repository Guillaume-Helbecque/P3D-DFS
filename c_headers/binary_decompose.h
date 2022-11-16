#ifndef BINARY_DECOMPOSE_H
#define BINARY_DECOMPOSE_H

#include <vector>
#include <memory>

#include <base_decompose.h>
#include <binary_subproblem.h>


class DecomposeBinary : public DecomposeBase<BinarySubproblem>
{
public:
    std::vector<std::unique_ptr<BinarySubproblem>> operator()(BinarySubproblem& n){
        std::vector<std::unique_ptr<BinarySubproblem>>children;

        //generates left/right child of parent node n
        //...maybe just copy construct and modify child here (feels weird to have branching logic hidden in ctor...)
        auto tmp2 = std::make_unique<BinarySubproblem>(n,1);
        children.push_back(std::move(tmp2));
        auto tmp1 = std::make_unique<BinarySubproblem>(n,0);
        children.push_back(std::move(tmp1));

        return children;
    }
};

#endif
