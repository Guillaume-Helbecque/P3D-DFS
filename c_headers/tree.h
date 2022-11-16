#ifndef TREE_H
#define TREE_H

#include <stack>
#include <memory>

#include <base_decompose.h>
#include <base_subproblem.h>

template<class Subproblem>
class Tree
{
public:
    Tree(DecomposeBase<Subproblem>& _decompose) :
        decompose(_decompose)
    {}

    bool empty(){
        return stack.empty();
    };

    size_t size(){
        return stack.size();
    };

    std::unique_ptr<Subproblem> top(){
        return std::move(stack.top());
    };

    void pop(){
        stack.pop();
    };

    std::unique_ptr<Subproblem> take(){
        std::unique_ptr<Subproblem> n=(empty())?nullptr:top();
        if(n) pop();
        return n;
    };

    void insert(std::unique_ptr<Subproblem>& n){
        stack.push(std::move(n));
    };

    void insert(std::vector<std::unique_ptr<Subproblem>> ns){
        for(auto &n : ns)
            insert(n);
    };

    std::vector<std::unique_ptr<Subproblem>> branch(Subproblem& n)
    {
        std::vector<std::unique_ptr<Subproblem>>ns(decompose(n));
        return ns;
    }

    void explore(std::unique_ptr<Subproblem>& s)
    {
        insert(s);

        unsigned count_leaves = 0;

        std::unique_ptr<Subproblem> n;
        while(n = take()){
            if(n->is_leaf()){
                ++count_leaves;
            }else{
                insert(branch(*n));
            }
        }

        std::cout<<"leaves\t"<<count_leaves<<"\n";
    }


private:
    std::stack<std::unique_ptr<Subproblem>>stack;
    DecomposeBase<Subproblem>& decompose;
};

#endif
