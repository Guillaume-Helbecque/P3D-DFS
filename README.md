# P3D-DFS
This repository contains the Chapel implementation of our Productivity- and Performance-aware Parallel Distributed Depth-First Search algorithm, namely P3D-DFS. The latter is a generic algorithm that can be instantiated on numerous tree-based problems. It is based on the `DistBag_DFS` distributed data structure, and employs an underlying Work Stealing (WS) mechanism to balance workload across multiple Chapel's locales.

## Chapel
[Chapel](https://chapel-lang.org/) is a programming language designed for productive parallel computing on large-scale systems.
Chapel supports a multi-threaded execution model via high-level abstractions for data parallelism, task parallelism, concurrency, and nested parallelism. Chapel's locale type enables users to specify and reason about the placement of data and tasks on a target architecture in order to tune for locality and affinity. Chapel supports global-view data aggregates with user-defined implementations, permitting operations on distributed data structures to be expressed in a natural manner.

Our Chapel codes rely on version 1.29.0. <br/>
The corresponding Chapel's version is downloadable at: https://github.com/chapel-lang/chapel/releases.

## The `DistBag_DFS` distributed data structure
The `DistBag_DFS` distributed data structure is a parallel-safe distributed multi-pool implementation that is unordered and incorporates a WS mechanism that balances workload across multiple locales, transparently to the user. It can contain either predefined-Chapel types, user-defined types or external ones (*e.g.* C structures).
This data structure has been derived from the `DistBag` data structure supplied is the `DistributedBag` Chapel's module, and revised in two different ways: (1) we propose a new scheduling policy of its elements as well as a new synchronization mechanism using non-blocking split-deques, and (2) we redefine the underlying WS mechanism.

## Compilation & Execution
- **Step 1:** [Set up your Chapel environment](https://chapel-lang.org/docs/usingchapel/chplenv.html) according to the machine on which your code is expected to run, and [build Chapel](https://chapel-lang.org/docs/usingchapel/building.html).
- **Step 2:** Compile with `make` and execute with:
```
./main.o --mode=distributed ${problem-specific options} -nl 2
```
where:
- `--mode` is the parallel execution mode, *i.e.* `multicore` or `distributed`;
- For the list of supported problems and options, see below;
- `-nl` is the number of Chapel's process(es), typically the number of computer nodes in distributed setting.

## Supported problems

### Branch-and-Bound algorithms (B&B)
B&B are exact optimization algorithms constructing implicity trees by successively applying *branching*, *bounding* and *pruning* operators. Each tree node corresponds to a subproblem (the initial problem defined on a restricted domain) and children nodes are obtained by further restricting the search space.

##### The Permutation Flow-shop Scheduling Problem (PFSP)
The PFSP consists in finding an optimal processing order (a permutation) for $n$ jobs on $m$ machines, such that the completion time of the last job on the last machine (makespan) is minimized.

Different B&B lower bounds are supported *via* `--lb`:
- `lb1`: a simple one-machine bound which can be computed in $\mathcal{O}(mn)$ steps per supproblem;
- `lb1_d`: a fast implementation of `lb1`, which can be compute in $\mathcal{O}(m)$ steps per supproblem;
- `lb2`: a two-machine bound which relies on the exact resolution of two-machine problems obtained by relaxing capacity constraints on all machines, with the exception of a pair of machines \(M<sub>u</sub>,M<sub>v</sub>\)<sub>1<=u<v<=m</sub>, and taking the maximum over all $\frac{m(m-1)}{2}$ machine-pairs. It can be computed in $\mathcal{O}(m^2n)$ steps per subproblem.

Moreover, the commonly used Taillard's instances are considered as test-cases, and can be specified *via* `--inst=n`; $n$ being an interger between $1$ and $120$. The initial upper bound `ub` is also configurable using `opt` to prove the optimality of the best-known optimal solution, or `inf` to search the optimal solution from scracth.

Example:
```
./main_pfsp.o --mode=distributed --inst=14 --lb=lb1_d --ub=opt -nl 2
```

### Backtracking algorithms
Backtracking is an algorithmic technique for solving problems recursively by trying to build a solution incrementally, one piece at a time, removing those solutions that fail to satisfy the constraints of the problem at any point in time.

##### The Unbalanced Tree-Search benchmark (UTS)
The UTS benchmark consists in counting the number of nodes in an implicitly constructed tree that is parameterized in shape, depth, size and imbalance. UTS trees are generated using a process, in which the number of children of a node is a random variable with a given distribution.
Our implementation supports binomial trees (`--t=0`), *i.e.* each node has `m` children with probability `q` and has no children with probability $1-q$, where $q\in [0,1]$. When $mq < 1$, this process generates a finite tree, and the variation of subtree sizes increases dramatically as $mq$ approaches $1$. The root-specific branching factor `b` can be set sufficiently high to generate an interesting variety of subtree sizes below the root.
Another root-specific parameter is `r`. Multiple instances of a tree type can be generated by varying this parameter, hence providing a check on the validity of an implementation. Finally, to vary the granularity, we introduced the `g` parameter which controls the number of random number generaion(s) per decomposed node.

Example:
```
./main_uts.o --mode=distributed --t=0 --m=2 --q=0.499995 --b=2000 --r=38 --g=10 -nl 2
```

##### The N-Queens problem
The N-Queen problem consists in placing `N` chess queens on an $N \times N$ chessboard so that no two queens attack each other; thus, a solution requires that no two queens share the same row, column, or diagonal.

Example:
```
./main_nqueens.o --mode=distributed --N=13 -nl 2
```

## Future improvements
- Perform low-level investigations and optimizations of the `DistBag-DFS` distributed data structure, as well as the underlying WS mechanism.
- Make PFSP more flexible, *e.g.* considering advanced B&B branching techniques.
- Extend the list of supported problems, *e.g.* the Quadratic Assignment Problem (QAP), the Traveling Salesman Problem (TSP).

## Contributors
- Guillaume Helbecque (maintainer), Université de Lille, CNRS/CRIStAL UMR 9189, Inria Lille-Nord Europe, France
- Jan Gmys, Inria Lille-Nord Europe, France
- Tiago Carneiro, Université du Luxembourg, FSTM, Luxembourg
- Nouredine Melab, Université de Lille, CNRS/CRIStAL UMR 9189, Inria Lille-Nord Europe, France
- Pascal Bouvry, Université du Luxembourg, DCS-FSTM/SnT, Luxembourg
