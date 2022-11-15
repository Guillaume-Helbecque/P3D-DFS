#ifndef BINARY_SUBPROBLEM_H
#define BINARY_SUBPROBLEM_H

#include <vector>
#include <iostream>

#include <base_subproblem.h>

class BinarySubproblem : public Subproblem
{
public:
    BinarySubproblem(int _size) : size(_size),limit1(-1),depth(0),values(std::vector<int>(size))
    {
    }

    BinarySubproblem(const BinarySubproblem& father, int index) : size(father.size),limit1(father.limit1),depth(father.depth+1),values(father.values)
    {
        limit1++;
        values[limit1] = index;
    }

    bool is_leaf() const
    {
        return depth == size;
    };

    int size;
    int limit1;
    int depth;

    std::vector<int> values;

    friend std::ostream& operator << (std::ostream& stream, const BinarySubproblem& s);
};

std::ostream&
operator << (std::ostream& stream, const BinarySubproblem& s);

#endif
