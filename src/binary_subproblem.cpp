#include <numeric>
#include <algorithm>

#include <binary_subproblem.h>

// write subproblem to stream
std::ostream&
operator << (std::ostream& stream, const BinarySubproblem& s)
{
    //print depth, limits, cost, ...

    //print schedule
    for (auto &c : s.values) {
        stream << c << " ";
    }

    return stream;
}
