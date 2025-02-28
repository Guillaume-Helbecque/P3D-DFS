# The 0/1-Knapsack problem

### Formulation

Given a set of $n$ items, where each item $i$ has a profit $p_i$ and weight $w_i$ associated with it. A binary decision variable $x_i$ is used to determine whether the item is selected or not. The goal is to choose a subset of items that maximizes the total profit, while ensuring the total weight of the selected items does not exceed a specified maximum weight $W$. Typically, the coefficients are scaled to integer values and are assumed to be positive. Formally, it is defined as:

$$\text{maximize}\quad \sum_{i=1}^{n}p_{i}x_{i}$$
$$\text{subject to }\quad \sum_{i=1}^{n}w_{i}x_{i}\leq W,$$
$$\text{with }\quad x_{i}\in \\\{0,1\\\}, \forall i \in \\\{1,\ldots,n\\\}.$$

### Configuration options

```
./main_knapsack.out {...}
```
where the available options are:
- **`--inst`**: file containing the data
  - must be placed in the `./instances` folder and formatted as follows:
  ```
  n W
  list of profits (delimited with spaces)
  list of weights (delimited with spaces)
  ```

- **`--ub`**: upper bound function
  - `dantzig`: implementation of Dantzig's bound [1] (default)
  - `martello`: implementation of Martello and Toth's bound [2]

- **`--lb`**: initial lower bound (LB)
  - `opt`: initialize the LB to the best solution known (default)
  - `inf`: initialize the LB to 0, leading to a search from scratch
  - `{NUM}`: initialize the LB to the given number

Specifically for targeting hard Pisinger's instances [3], the following parameters can be used (and `--inst` omitted):
- **`--n`**: number of items
  - any positive integer (`100` by default)

- **`--r`**: range of coefficients
  - any positive integer (`10000` by default)

- **`--t`**: type of instance
  - `1`: uncorrelated (default)
  - `2`: weakly correlated
  - `3`: strongly correlated
  - `4`: inverse strongly correlated
  - `5`: almost strongly correlated
  - `6`: subset sum
  - `9`: uncorrelated with similar weights
  - `11`: uncorrelated spanner, span(2,10)
  - `12`: weakly correlated spanner, span(2,10)
  - `13`: strongly correlated spanner, span(2,10)
  - `14`: multiple strongly correlated, mstr(3R/10,2R/10,6)
  - `15`: profit ceiling, pceil(3)
  - `16`: circle, circle(2/3)

- **`--id`**: index of the instance
  - any positive integer (`1` by default)

- **`--s`**: number of instances in series
  - any positive integer (`100` by default)

### References

1. G. B. Dantzig. (1957) Discrete-Variable Extremum Problems. *Operations Research*, 5(2):266-288. DOI: [10.1287/opre.5.2.266](https://doi.org/10.1287/opre.5.2.266).
2. S. Martello, P. Toth. (1977) An upper bound for the zero-one knapsack problem and a branch and bound algorithm. *European Journal of Operational Research*, 1(3):169-175. DOI: [10.1016/0377-2217(77)90024-8](https://doi.org/10.1016/0377-2217(77)90024-8).
3. D. Pisinger. (2005) Where are the hard knapsack problems?. *Computers & Operations Research*, 32(9):2271-2284. DOI: [10.1016/j.cor.2004.03.002](https://doi.org/10.1016/j.cor.2004.03.002).
