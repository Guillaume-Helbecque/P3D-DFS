# P3D-DFS
Chapel-based implementation of our Productivity- and Performance-aware Parallel Distributed Depth-First Search algorithm, namely P3D-DFS. The latter is a generic and general algorithm that can be instantiated on numerous tree-based problems. It is based on the `DistBag-DFS` distributed data structure, which employs an underlying Work Stealing (WS) mechanism to balance workload across multiple Chapel's locales.

## Chapel
[Chapel](https://chapel-lang.org/) is a programming language designed for productive parallel computing on large-scale systems.
Chapel supports a multi-threaded execution model via high-level abstractions for data parallelism, task parallelism, concurrency, and nested parallelism. Chapel's locale type enables users to specify and reason about the placement of data and tasks on a target architecture in order to tune for locality and affinity. Chapel supports global-view data aggregates with user-defined implementations, permitting operations on distributed data structures to be expressed in a natural manner.

Our implementation relies on Chapel 2.0.0 and might not compile and run for other versions.

## The `DistBag-DFS` distributed data structure
The `DistBag-DFS` distributed data structure is a parallel-safe distributed multi-pool implementation that is unordered and incorporates a WS mechanism that balances workload across multiple locales, transparently to the user. It can contain either predefined-Chapel types, user-defined types or external ones (*e.g.* C structures).
This data structure has been derived from the `DistBag` data structure supplied is the `DistributedBag` Chapel's module, and revised in two different ways: (1) we propose a new scheduling policy of its elements as well as a new synchronization mechanism using non-blocking split-deques, and (2) we redefine the underlying WS mechanism.

## Compilation & Execution
- **Step 1:** [Set up your Chapel environment](https://chapel-lang.org/docs/usingchapel/chplenv.html) according to the machine on which your code is expected to run, and [build Chapel](https://chapel-lang.org/docs/usingchapel/building.html). Some predefined
configuration scripts are provided in the [chpl_config](./chpl_config) directory.
- **Step 2:** Compile with `make` and execute with:
```
./main.o --mode=distributed ${problem-specific options} -nl 2
```
where:
- `--mode` is the execution mode, *i.e.* `sequential`, `multicore`, or `distributed`;
- For the list of supported problems and options, see below;
- `-nl` is the number of Chapel's process(es), typically the number of computer nodes in distributed setting.

## Supported problems

### Branch-and-Bound algorithms (B&B)
B&B are exact optimization algorithms exploring implicitly constructed trees by successively applying *branching*, *bounding* and *pruning* operators. Each tree node corresponds to a subproblem (the initial problem defined on a restricted domain) and children nodes are obtained by further restricting the search space.

- [The Permutation Flow-shop Scheduling problem](./benchmarks/PFSP) (PFSP)
- [The 0/1-Knapsack problem](./benchmarks/Knapsack)

### Backtracking algorithms
Backtracking is an algorithmic technique for solving problems recursively by trying to build a solution incrementally, one piece at a time, removing those solutions that fail to satisfy the constraints of the problem at any point in time.

- [The Unbalanced Tree-Search benchmark](./benchmarks/UTS) (UTS)
- [The N-Queens problem](./benchmarks/NQueens)

## Experimental results

The following figures show the absolute speed-up achieved by P3D-DFS and MPI+X baseline implementations on large unbalanced tree-based
problems, considering different granularities (fine, medium, coarse). For each figure, most coarse-grained is top-right, most
fine-grained is bottom-left.

<table><tr><td>

![results_pfsp_dist](https://github.com/Guillaume-Helbecque/P3D-DFS/assets/72358009/b8a99db2-9b3c-49ec-8fad-33d6e5020af1)
<p align = "center">
Fig.1 - P3D-DFS vs. MPI-PBB on B&B applied to PFSP.
</p>

</td><td>

![results_uts_dist](https://github.com/Guillaume-Helbecque/P3D-DFS/assets/72358009/bd603a08-46d1-4829-a92f-7f15cf72970b)
<p align = "center">
Fig.2 - P3D-DFS vs. MPI-PUTS on UTS.
</p>

</td></tr></table>

## Related publications
1. G. Helbecque, J. Gmys, N. Melab, T. Carneiro, P. Bouvry. Parallel distributed productivity-aware tree-search using Chapel. *Concurrency Computation Practice Experience*, 35(27):e7874, 2023. DOI: [10.1002/cpe.7874](https://onlinelibrary.wiley.com/doi/10.1002/cpe.7874).
2. G. Helbecque, J. Gmys, T. Carneiro, N. Melab, P. Bouvry. Towards a scalable load balancing for productivity-aware tree-search. *The 10th Annual Chapel Implementers and Users Workshop (CHIUW)*, June 2023, online.
3. G. Helbecque, J. Gmys, N. Melab, T. Carneiro, P. Bouvry. Productivity-aware Parallel Distributed Tree-Search for Exact Optimization. *International Conference on Optimization and Learning (OLA)*, May 2023, Malaga, Spain.
