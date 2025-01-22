[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.7328540.svg)](https://doi.org/10.5281/zenodo.7328540)

# P3D-DFS
Chapel-based implementation of our Productivity- and Performance-aware Parallel Distributed Depth-First Search algorithm, namely P3D-DFS. The latter is a generic and general algorithm that can be instantiated on numerous tree-based problems. It is based on the `DistBag_DFS` distributed data structure, which employs an underlying Work Stealing (WS) mechanism to balance workload across multiple Chapel's locales.

The `DistBag_DFS` distributed data structure is a parallel-safe distributed multi-pool implementation that is unordered and incorporates a WS mechanism that balances workload across multiple locales, transparently to the user. It can contain either predefined-Chapel types, user-defined types or external ones (*e.g.* C structures).
This data structure has been derived from the `DistBag` data structure supplied is the `DistributedBag` Chapel's module, and revised in two different ways: (1) we propose a new scheduling policy of its elements as well as a new synchronization mechanism using non-blocking split-deques, and (2) we redefine the underlying WS mechanism.

### Prerequisites

[Chapel](https://chapel-lang.org/) >= 2.0 (tested with 2.3.0)

The [chpl_config](./chpl_config) directory contains predefined shell scripts for downloading, configuring, and building the Chapel compiler from source.

### Compilation and execution
- **Step 1:** [Set up your Chapel environment](https://chapel-lang.org/docs/usingchapel/chplenv.html) according to the machine on which your code is expected to run, and [build Chapel](https://chapel-lang.org/docs/usingchapel/building.html).
- **Step 2:** Compile with `make` and execute with:
```
./main.o --mode=distributed ${problem-specific options} -nl 2
```
where:
- `--mode` is the execution mode, *i.e.* `sequential`, `multicore`, or `distributed`;
- For the list of supported problems and options, see below;
- `-nl` is the number of Chapel's process(es), typically the number of computer nodes in distributed setting.

### Supported problems

- [The Permutation Flowshop Scheduling problem](./benchmarks/PFSP) (PFSP)
- [The 0/1-Knapsack problem](./benchmarks/Knapsack)
- [The Unbalanced Tree Search benchmark](./benchmarks/UTS) (UTS)
- [The N-Queens problem](./benchmarks/NQueens)

### Plug your own problem

To come...

### Related publications
1. G. Helbecque, T. Carneiro, N. Melab, J. Gmys, P. Bouvry. PGAS Data Structure for Unbalanced Tree-Based Algorithms at Scale. *Computational Science – ICCS 2024 (ICCS)*. vol 14834, 2024. DOI: [10.1007/978-3-031-63759-9_13](https://doi.org/10.1007/978-3-031-63759-9_13).
2. G. Helbecque, J. Gmys, N. Melab, T. Carneiro, P. Bouvry. Parallel distributed productivity-aware tree-search using Chapel. *Concurrency Computation Practice Experience*, 35(27):e7874, 2023. DOI: [10.1002/cpe.7874](https://onlinelibrary.wiley.com/doi/10.1002/cpe.7874).
3. G. Helbecque, J. Gmys, T. Carneiro, N. Melab, P. Bouvry. Towards a scalable load balancing for productivity-aware tree-search. *The 10th Annual Chapel Implementers and Users Workshop (CHIUW)*, June 2023, online.
4. G. Helbecque, J. Gmys, N. Melab, T. Carneiro, P. Bouvry. Productivity-aware Parallel Distributed Tree-Search for Exact Optimization. *International Conference on Optimization and Learning (OLA)*, May 2023, Malaga, Spain.
