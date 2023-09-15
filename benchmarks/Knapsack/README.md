# The 0/1-Knapsack problem

Given a set of $N$ items, each item $i$ having a weight ${w_i}$ and a profit ${p_i}$, the problem is to determine which items to include in the collection so that the total weight is less than or equal to a given limit $W$ and the total profit is as large as possible. The Pisinger's instances [1] are supported as test-cases. The initial upper bound `ub` is configurable using `opt` to prove the optimality of the best-known optimal solution, or `inf` to search the optimal solution from scracth.

### Launch & Command-line parameters

```
./main_knapsack.o --name=file_name --ub=opt
```
where:
- `file_name` (`str`): name of the file containing the data. Pisinger's instances can be specified using the `knapPI_t_n_r_i.txt` template, where the possible values of `t`, `n`, `r`, and `i` are detailed in [Pisinger_genhard.c](./c_sources/Pisinger_genhard.c). User-defined instances must be placed in the `./instances/data` folder and formatted as follows:
```
N W
list of profits (delimited with spaces)
list of weights (delimited with spaces)
```
By default, `default.txt` is solved:
<!--
"default.txt" corresponds to instance "p07" of:
https://people.sc.fsu.edu/~jburkardt/datasets/knapsack_01/knapsack_01.html
-->
```
15  750
135 139 149 150 156 163 173 184 192 201 210 214 221 229 240
70  73  77  80  82  87  90  94  98  106 110 113 115 118 120
```
- `ub` (`str`): initial upper bound (`opt` by default). If the user want to specify a value, it must be written in a file named `filename_optimal.txt` (where `filename.txt` contains the instance data) and placed in the `./instances/data` folder.

### References

1. D. Pisinger. (2005) Where are the hard knapsack problems?. *Computers & Operations Research*, 32(9):2271-2284. DOI: [10.1016/j.cor.2004.03.002](https://doi.org/10.1016/j.cor.2004.03.002).
