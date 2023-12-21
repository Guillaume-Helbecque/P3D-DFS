# The Permutation Flow-shop Scheduling problem (PFSP)

The problem consists in finding an optimal processing order (a permutation) for $n$ jobs on $m$ machines, such that the completion time of the last job on the last machine (makespan) is minimized. The commonly used Taillard's [1] and VRF's [2] instances are supported as test-cases. The initial upper bound `ub` is also configurable using `opt` to prove the optimality of the best-known optimal solution, or `inf` to search the optimal solution from scratch.

Different B&B lower bounds are supported *via* `--lb`:
- `lb1`: a simple one-machine bound which can be computed in $\mathcal{O}(mn)$ steps per subproblem;
- `lb1_d`: a fast implementation of `lb1`, which can be compute in $\mathcal{O}(m)$ steps per subproblem;
- `lb2`: a two-machine bound which relies on the exact resolution of two-machine problems obtained by relaxing capacity constraints on all machines, with the exception of a pair of machines \(M<sub>u</sub>,M<sub>v</sub>\)<sub>1<=u<v<=m</sub>, and taking the maximum over all $\frac{m(m-1)}{2}$ machine-pairs. It can be computed in $\mathcal{O}(m^2n)$ steps per subproblem.

In addition, different B&B branching rules are supported *via* `--br`: `fwd`, `bwd`, `alt`, `maxSum`, `minMin`, and `minBranch`. The latter are defined in [3].

### Launch & Command-line parameters

```chapel
./main_pfsp.o --inst=ta13 --lb=lb1_d --br=fwd --ub=opt
```
where:
- `inst` (`str`): instance to solve (`ta14` by default). Taillard's instances can be specified using `taXXX` where `XXX` is the instance's index (between $1$ and $120$). VRF's instances can be specified using `VFRi_j_k_Gap.txt`, where `i` is the number of jobs, `j` the number of machines, and `k` the instance's index;
- `lb` (`str`): B&B lower bound function (`lb1` by default);
- `br` (`str`): B&B branching rule (`fwd` by default);
- `ub` (`str`): initial upper bound (`opt` by default).

### References

1. E. Taillard. (1993) Benchmarks for basic scheduling problems. *European Journal of Operational Research*, 64(2):278-285. DOI: [10.1016/0377-2217(93)90182-M](https://doi.org/10.1016/0377-2217(93)90182-M).
2. E. Vallada, R. Ruiz, and J. M. Framinan. (2015) New hard benchmark for flowshop scheduling problems minimising makespan. *European Journal of Operational Research*, 240(3):666-677. DOI: [10.1016/j.ejor.2014.07.033](https://doi.org/10.1016/j.ejor.2014.07.033).
3. J. Gmys, M. Mezmaz, N. Melab, and D. Tuyttens. (2020) A computationally efficient Branch-and-Bound algorithm for the permutation flow-shop scheduling problem. *European Journal of Operational Research*, 284(3):814–833. DOI: [10.1016/j.ejor.2020.01.039](https://doi.org/10.1016/j.ejor.2020.01.039)
