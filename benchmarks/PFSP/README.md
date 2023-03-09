# The Permutation Flow-shop Scheduling problem (PFSP)

The problem consists in finding an optimal processing order (a permutation) for $n$ jobs on $m$ machines, such that the completion time of the last job on the last machine (makespan) is minimized. The commonly used Taillard's instances are considered as test-cases. The initial upper bound `ub` is also configurable using `opt` to prove the optimality of the best-known optimal solution, or `inf` to search the optimal solution from scracth.

Different B&B lower bounds are supported *via* `--lb`:
- `lb1`: a simple one-machine bound which can be computed in $\mathcal{O}(mn)$ steps per supproblem;
- `lb1_d`: a fast implementation of `lb1`, which can be compute in $\mathcal{O}(m)$ steps per supproblem;
- `lb2`: a two-machine bound which relies on the exact resolution of two-machine problems obtained by relaxing capacity constraints on all machines, with the exception of a pair of machines \(M<sub>u</sub>,M<sub>v</sub>\)<sub>1<=u<v<=m</sub>, and taking the maximum over all $\frac{m(m-1)}{2}$ machine-pairs. It can be computed in $\mathcal{O}(m^2n)$ steps per subproblem.

### Launch & Command-line parameters

```chapel
./main_pfsp.o --inst=10 --lb=lb1_d --ub=opt
```
where:
- `inst` (`int`): Taillard instance to solve (between $1$ and $120$, $14$ by default);
- `lb` (`str`): B&B lower bound function (`lb1` by default);
- `ub` (`str`): initial upper bound (`opt` by default);

### References

[1] E. Taillard. (1993) Benchmarks for basic scheduling problems. European Journal of Operational Research, 64(2):278-285, https://doi.org/10.1016/0377-2217(93)90182-M.
