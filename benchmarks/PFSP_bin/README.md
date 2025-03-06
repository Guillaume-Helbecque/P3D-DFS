# The Permutation Flowshop Scheduling Problem (PFSP)

### Formulation

The problem consists in finding an optimal processing order (a permutation) for $n$ jobs on $m$ machines, such that the completion time of the last job on the last machine (makespan) is minimized. The commonly used Taillard's [1] and VRF's [2] instances are supported as test-cases.

### Configuration options

```
./main_pfsp.out {...}
```

where the available options are:
- **`--inst`**: instance to solve
  - `taXXX`: Taillard's instance where `XXX` is the instance's index between `001` and `120` (`ta014` by default)
  - `VFRi_j_k_Gap.txt`: VRF's instance where `i` is the number of jobs, `j` the number of machines, and `k` the instance's index

<!-- TODO: give references -->
- **`--lb`**: lower bound function
  - `lb1`: one-machine bound which can be computed in $\mathcal{O}(mn)$ steps per subproblem (default)
  - `lb1_d`: fast implementation of `lb1`, which can be compute in $\mathcal{O}(m)$ steps per subproblem
  - `lb2`: two-machine bound which can be computed in $\mathcal{O}(m^2n)$ steps per subproblem
  <!-- a two-machine bound which relies on the exact resolution of two-machine problems obtained by relaxing capacity constraints on all machines, with the exception of a pair of machines \(M<sub>u</sub>,M<sub>v</sub>\)<sub>1<=u<v<=m</sub>, and taking the maximum over all $\frac{m(m-1)}{2}$ machine-pairs. It can be computed in $\mathcal{O}(m^2n)$ steps per subproblem. -->

- **`--br`**: branching rule, as defined in [3] (only available for `--lb lb1_d`)
  - `fwd`: forward (default)
  - `bwd`: backward
  - `alt`: alternate
  - `maxSum`: MaxSum
  - `minMin`: MinMin
  - `minBranch`: MinBranch

- **`--ub`**: initial upper bound (UB)
  - `opt`: initialize the UB to the best solution known (default)
  - `inf`: initialize the UB to $+\infty$, leading to a search from scratch
  - `{NUM}`: initialize the UB to the given number

### References

1. E. Taillard. (1993) Benchmarks for basic scheduling problems. *European Journal of Operational Research*, 64(2):278-285. DOI: [10.1016/0377-2217(93)90182-M](https://doi.org/10.1016/0377-2217(93)90182-M).
2. E. Vallada, R. Ruiz, and J. M. Framinan. (2015) New hard benchmark for flowshop scheduling problems minimising makespan. *European Journal of Operational Research*, 240(3):666-677. DOI: [10.1016/j.ejor.2014.07.033](https://doi.org/10.1016/j.ejor.2014.07.033).
3. J. Gmys, M. Mezmaz, N. Melab, and D. Tuyttens. (2020) A computationally efficient Branch-and-Bound algorithm for the permutation flow-shop scheduling problem. *European Journal of Operational Research*, 284(3):814–833. DOI: [10.1016/j.ejor.2020.01.039](https://doi.org/10.1016/j.ejor.2020.01.039).
