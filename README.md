[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.7328540.svg)](https://doi.org/10.5281/zenodo.7328540)

# Productivity- and Performance-aware Parallel Distributed Depth-First Search (P3D-DFS)

Set of parallel Branch-and-Bound (B&B) skeletons in Chapel targeting CPU-based systems at every scale. This project aims to investigate the Partitioned Global Address Space (PGAS) programming model (as alternative to MPI+X) for implementing parallel optimization algorithms and to promote the extensibility of the approaches to make them accessible to the community.

The parallelization relies on the parallel tree exploration model, in which several CPU threads explore disjoint sub-spaces of solutions (branches of the B&B tree) in parallel. In this scheme, each CPU thread manages a separate pool of work in a Depth-First Search (DFS) order, and dynamic load balancing (work stealing) occurs to manage irregular trees. The efficient implementation of these mechanisms, as well as the genericity of the implementations, are managed by our high-level and highly parallel `distBag` data structure (also known as `distBag_DFS` or `DistBag_DFS`). The latter has been integrated into the Chapel language as the [`DistributedBag`](https://chapel-lang.org/docs/modules/packages/DistributedBag.html) package module.

### Prerequisites

[Chapel](https://chapel-lang.org/) >= 2.0 (tested with 2.10.0)

The [chpl_config](./chpl_config) directory contains predefined shell scripts for downloading, configuring, and building the Chapel compiler from source.

### Compilation and configuration options

- **Step 1:** [Set up your Chapel environment](https://chapel-lang.org/docs/usingchapel/chplenv.html) according to the target system, and [build Chapel](https://chapel-lang.org/docs/usingchapel/building.html).

- **Step 2:** Compile with `make` and execute with:

```
./main.out {...}
```

where the available options are:
- **`--mode`**: parallel execution mode
  - `sequential`: single-core execution, without parallel feature (default)
  - `multicore`: single-node multi-core execution
  - `distributed`: multi-node multi-core execution

- **`--findAll`**: find all optimal solutions

- **`--activeSet`**: compute and distribute an initial set of elements

- **`--saveTime`**: save execution time in a file

- **`-nl`**: number of Chapel's locales
  - any positive integer, typically the number of compute nodes

- **`--help`** or **`-h`**: help message

Other problem-specific options are supported; see next section.

### Supported problems

The B&B skeletons have already been tested on the following benchmark problems:
- [The Permutation Flowshop Scheduling problem](./benchmarks/PFSP) (PFSP)
- [The 0/1-Knapsack problem](./benchmarks/Knapsack)
- [The Quadratic Assignment problem](./benchmarks/QAP) (QAP)
- [The Unbalanced Tree Search benchmark](./benchmarks/UTS) (UTS)
- [The N-Queens problem](./benchmarks/NQueens)

### Integrate your own problem

The B&B skeletons are designed to be problem-independent, allowing users to integrate their own optimization problems while reusing the underlying parallel tree exploration and load-balancing mechanisms.

To facilitate this integration, we provide a [`main_template.chpl`](./main_template.chpl) file that serves as a starting point for implementing a new problem. Existing benchmark implementations in [./benchmarks/](./benchmarks/) can also be used as concrete examples.

The integration mainly consists of three steps:

**Step 1: Implement your problem-specific components.**

Start by copying `main_template.chpl` and adapting the following components:

- **`MyNode`**: a Chapel record representing a node in the search tree. It must provide three initializers:
  - A default initializer.
  - A root initializer, taking the problem instance as an argument.
  - A copy initializer, taking another node as an argument.
- **`MyProblem`**: a class inheriting from the generic `Problem` class, implementing the problem-specific logic required by the B&B algorithm.
- **Problem-specific procedures**: implement the required operations, such as branching, bounding, and solution evaluation, following the interfaces illustrated in the existing benchmarks.

These modules must follow the interfaces expected by the generic B&B skeleton.

**Step 2: Create your main program.**

The template already provides a generic entry point:

```chapel
proc main(args: [] string): int
{
  // TODO: Initialize your problem instance.
  var myProblem = new MyProblem(/* problem-specific options here */);
  // TODO: Initialize your root node.
  var root = new MyNode(/* args */);

  // Launch the generic Branch-and-Bound search.
  // No modification is required here.
  run_search(args, root, myProblem);

  return 0;
}
```

Adapt the initialization of `MyProblem` to include any problem-specific configuration options.

The `run_search` procedure connects your implementation to the generic B&B skeleton and handles the selected execution mode, allowing you to focus on the optimization problem rather than the underlying parallelization mechanisms.

**Step 3: Compile and execute.**

The provided `Makefile` provides a generic compilation rule for all `main_*.chpl` files. Simply ensure that your implementation follows this naming convention (e.g., `main_myproblem.chpl`), then compile using:

```bash
make main_template.out
```

Once compiled, execute your problem using any of the supported options:

```bash
./main_myproblem.out {...}
```

Additional problem-specific configuration options can be passed through the command line.

### Related publications

1. J.-P. Valois, G. Helbecque, N. Melab. Efficient and scalable branch-and-bound algorithm for exact qubit allocation. *Future Generation Computer Systems*, 179:108342, 2026. DOI: [10.1016/j.future.2025.108342](https://doi.org/10.1016/j.future.2025.108342).
2. G. Helbecque. *PGAS-based Parallel Branch-and-Bound for Ultra-Scale GPU-powered Supercomputers*. Ph.D. thesis. Université de Lille, Université du Luxembourg. 2025. URL: https://theses.fr/2025ULILB003.
3. G. Helbecque, T. Carneiro, N. Melab, J. Gmys, P. Bouvry. PGAS Data Structure for Unbalanced Tree-Based Algorithms at Scale. *Computational Science – ICCS 2024 (ICCS)*. vol 14834, 2024. DOI: [10.1007/978-3-031-63759-9_13](https://doi.org/10.1007/978-3-031-63759-9_13).
4. G. Helbecque, J. Gmys, N. Melab, T. Carneiro, P. Bouvry. Parallel distributed productivity-aware tree search using Chapel. *Concurrency Computation Practice Experience*, 35(27):e7874, 2023. DOI: [10.1002/cpe.7874](https://onlinelibrary.wiley.com/doi/10.1002/cpe.7874).
