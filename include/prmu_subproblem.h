#ifndef PRMU_SUBPROBLEM_H
#define PRMU_SUBPROBLEM_H

#define BEGIN_ORDER 0
#define END_ORDER 1

#include <vector>
#include <iostream>
#include <memory>

#include <base_subproblem.h>


class PermutationSubproblem : public Subproblem
{
public:
    PermutationSubproblem(int _size);
    PermutationSubproblem(const PermutationSubproblem& father);
    PermutationSubproblem(const PermutationSubproblem& father, const int index, const int begin_end = BEGIN_ORDER);

    bool is_leaf() const;

    friend std::ostream& operator << (std::ostream& stream, const PermutationSubproblem& s);

    int size;
    int depth;

    int limit1;
    int limit2;

    //could use something else than integers, but does it make sense? template or not?
    std::vector<int> schedule;
    // std::vector<std::string> schedule;
private:
};

std::ostream&
operator << (std::ostream& stream, const PermutationSubproblem& s);

#endif
