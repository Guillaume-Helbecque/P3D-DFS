# Parallel-DFS
This repository contains the Chapel implementation of our Productivity- and Performance-aware Parallel Distributed Depth-First Search algorithm, namely P3D-DFS. The latter is a generic algorithm that can be instantiated on numerous tree-based problems. It is based on the `DistBag-DFS` distributed data structure, and employs an underlying Work Stealing (WS) mechanism to balance workload across multiple Chapel's locales.

## Chapel
[Chapel](https://chapel-lang.org/) is a programming language designed for productive parallel computing on large-scale systems.
Chapel supports a multi-threaded execution model via high-level abstractions for data parallelism, task parallelism, concurrency, and nested parallelism. Chapel's locale type enables users to specify and reason about the placement of data and tasks on a target architecture in order to tune for locality and affinity. Chapel supports global-view data aggregates with user-defined implementations, permitting operations on distributed data structures to be expressed in a natural manner.

Our Chapel codes rely on version 1.27.0. <br/>
The corresponding Chapel's version is downloadable at: https://github.com/chapel-lang/chapel/releases.

## The `DistBag-DFS` distributed data structure
To come...

## Compilation & Execution
To come...

## Supported problems

### The Branch-and-Bound methods (B&B)
B&B are exact optimization algorithms constructing implicity trees by successively applying *branching*, *bounding* and *pruning* operators. Each tree node corresponds to a subproblem (the initial problem defined on a restricted domain) and children nodes are obtained by further restricting the search space. 

##### The Permutation Flow-shop Scheduling Problem (PFSP)
To come...

### The Unbalanced Tree-Search benchmark (UTS)
To come...

## Future improvements
- Perform low-level investigations and optimizations of the `DistBag-DFS` distributed data structure, as well as the underlying WS mechanism.
- Make B&B more flexible, *e.g.* considering advanced branching techniques.
- Extend the list of supported problems, *e.g.* the Quadratic Assignment Problem (QAP), the N-Queens problem, the Traveling Salesman Problem (TSP).

## Contributors
- Guillaume Helbecque (maintainer), Université de Lille, CNRS/CRIStAL UMR 9189, Inria Lille-Nord Europe, France
- Jan Gmys, Inria Lille-Nord Europe, France
- Tiago Carneiro, Université du Luxembourg, FSTM, Luxembourg
- Nouredine Melab, Université de Lille, CNRS/CRIStAL UMR 9189, Inria Lille-Nord Europe, France
- Pascal Bouvry, Université du Luxembourg, DCS-FSTM/SnT, Luxembourg
