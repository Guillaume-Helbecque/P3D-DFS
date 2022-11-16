#include <numeric>
#include <algorithm>

#include <prmu_subproblem.h>

//ctor for initial subproblem (root)
PermutationSubproblem::PermutationSubproblem(int _size) : size(_size),depth(0),limit1(-1),limit2(size),schedule(std::vector<int>(size))
// PermutationSubproblem::PermutationSubproblem(int _size) : size(_size),depth(0),limit1(-1),limit2(size),schedule(std::vector<std::string>(size))
{
    std::iota(schedule.begin(),schedule.end(),0);
}

//generate index^th child of father according to rule begin_end
PermutationSubproblem::PermutationSubproblem(const PermutationSubproblem& father) : size(father.size),depth(father.depth+1),limit1(father.limit1),limit2(father.limit2),schedule(father.schedule)
{

}

//generate index^th child of father according to rule begin_end
PermutationSubproblem::PermutationSubproblem(const PermutationSubproblem& father, const int index, const int begin_end) :  size(father.size),depth(father.depth+1),limit1(father.limit1),limit2(father.limit2),schedule(father.schedule)
{
    //branching logic .... move to decompose?

    depth = father.depth + 1;

    if(begin_end == BEGIN_ORDER){
        limit1++;

        //shift unscheduled
        auto tmp = schedule[index];
        for(int i=index; i>limit1; i--)
        {
            schedule[i]=schedule[i-1];
        }
        schedule[limit1]=tmp;
    }
    else if(begin_end == END_ORDER){
        limit2--;

        //shift unscheduled
        auto tmp = schedule[index];
        for(int i=index; i<limit2; i++)
        {
            schedule[i]=schedule[i+1];
        }
        schedule[limit2]=tmp;
    }
};


bool
PermutationSubproblem::is_leaf() const
{
    return depth == size;
}

// write subproblem to stream
std::ostream&
operator << (std::ostream& stream, const PermutationSubproblem& s)
{
    //print depth, limits, cost, ...

    //print schedule
    for (auto &c : s.schedule) {
        stream << c << " ";
    }

    return stream;
}
