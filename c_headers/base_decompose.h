#ifndef DECOMPOSE_H
#define DECOMPOSE_H

#include <vector>
#include <memory>

template <class T>
class DecomposeBase
{
public:
    virtual std::vector<std::unique_ptr<T>> operator()(T& n) = 0;
};

#endif
