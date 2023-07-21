# The 0/1-Knapsack problem

Given a set of $N$ items, each item $i$ having a weight ${w_i}$ and a profit ${p_i}$, the problem is to determine which items to include in the collection so that the total weight is less than or equal to a given limit $W$ and the total profit is as large as possible. Some of the Pisinger's [1] instances are supported as test-cases.

### Launch & Command-line parameters

```
./main_knapsack.o --name=file_name
```
where:
- `file_name` (`str`): name of the file containing the data. Pisinger's instances can be specified using `knapPI_t_N_r_i` where `t` is the instance type (1=ucorrelated, 2=weakly correlated, 3=strongly correlated), `N` the number of items, `r` the range of coefficients, and `i` the instance number ($1$ to $10$). User defined instances must be placed in the `./instances` folder and formated as follows:
```
N W
list of profits (delimited with spaces)
list of weights (delimited with spaces)
```
By default, `default.txt` is solved:
```
15  750
135 139 149 150 156 163 173 184 192 201 210 214 221 229 240
70  73  77  80  82  87  90  94  98  106 110 113 115 118 120
```

### References

[1] Pisinger, D. (2005) Where are the hard knapsack problems?. *Computers & Operations Research*, 32(9):2271-2284. DOI: [10.1016/j.cor.2004.03.002](https://doi.org/10.1016/j.cor.2004.03.002).
