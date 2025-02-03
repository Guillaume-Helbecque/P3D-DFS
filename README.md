[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.7328540.svg)](https://doi.org/10.5281/zenodo.7328540)

# Productivity- and Performance-aware Parallel Distributed Depth-First Search (P3D-DFS)

Set of parallel Branch-and-Bound (B&B) skeletons in Chapel targeting CPU-based systems at every scale. This project aims to investigate the Partitioned Global Address Space (PGAS) programming model (as alternative to MPI+X) for implementing parallel optimization algorithms and to promote the extensibility of the approaches to make them accessible to the community.

The parallelization relies on the parallel tree exploration model, in which several CPU threads explore disjoint sub-spaces of solutions (branches of the B&B tree) in parallel. In this scheme, each CPU thread manages a separate pool of work in a Depth-First Search (DFS) order, and dynamic load balancing (work stealing) occurs to manage irregular trees. The efficient implementation of these mechanisms, as well as the genericity of the implementations, are managed by our high-level and highly parallel `distBag` data structure (also known as `distBag_DFS` or `DistBag_DFS`). The latter has been integrated into the Chapel language as the [`DistributedBag`](https://chapel-lang.org/docs/modules/packages/DistributedBag.html) package module.

### Prerequisites

[Chapel](https://chapel-lang.org/) >= 2.0 (tested with 2.3.0)

The [chpl_config](./chpl_config) directory contains predefined shell scripts for downloading, configuring, and building the Chapel compiler from source.

### Compilation and configuration options

- **Step 1:** [Set up your Chapel environment](https://chapel-lang.org/docs/usingchapel/chplenv.html) according to the machine on which your code is expected to run, and [build Chapel](https://chapel-lang.org/docs/usingchapel/building.html).

- **Step 2:** Compile with `make` and execute with:

```
./main.out {...}
```

where the available options are:
- **`--mode`**: parallel execution mode
  - `sequential`: single-core execution, without parallel feature (default)
  - `multicore`: single-node multi-core execution
  - `distributed`: multi-node multi-core execution

- **`-nl`**: number of Chapel's locales
  - any positive integer, typically the number of compute nodes

- **`--help`** or **`-h`**: help message

Other problem-specific options are supported; see below.

### Supported problems

The B&B skeletons have already been tested on the following benchmark problems:
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
