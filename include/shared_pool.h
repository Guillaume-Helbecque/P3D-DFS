#ifndef SHARED_POOL_H
#define SHARED_POOL_H

#include <stack>
#include <memory>
#include <omp.h>

#include <base_subproblem.h>


template<class Subproblem>
class SharedPool
{
public:
    SharedPool() : nnodes(0){
        omp_init_lock(&lock);
    };

    bool empty(){
        bool ret;
        omp_set_lock(&lock);
        ret = stack.empty();
        omp_unset_lock(&lock);
        return ret;
    };

    size_t size(){
        return nnodes;
    };

    void nnodes_decr_one(){
        omp_set_lock(&lock);
        nnodes--;
        omp_unset_lock(&lock);
    };

    std::unique_ptr<Subproblem> top(){
        std::unique_ptr<Subproblem> ret;

        omp_set_lock(&lock);
        ret = std::move(stack.top());
        omp_unset_lock(&lock);

        return std::move(ret);
    };

    void pop(){
        omp_set_lock(&lock);
        stack.pop();
        omp_unset_lock(&lock);
    };

    std::unique_ptr<Subproblem> take(){
        omp_set_lock(&lock);
        std::unique_ptr<Subproblem> n=(stack.empty())?nullptr:std::move(stack.top());
        if(n)stack.pop();
        omp_unset_lock(&lock);
        return n;
    };

    void insert(std::unique_ptr<Subproblem>& n){
        omp_set_lock(&lock);
        stack.push(std::move(n));
        nnodes++;
        omp_unset_lock(&lock);
    };

    void insert(std::vector<std::unique_ptr<Subproblem>> ns){
        omp_set_lock(&lock);
        for(auto &n : ns){
            nnodes++;
            stack.push(std::move(n));
            // insert(n);
        }
        omp_unset_lock(&lock);
    };

private:
    unsigned long nnodes;
    std::stack<std::unique_ptr<Subproblem>>stack;

    omp_lock_t lock;

};

#endif
