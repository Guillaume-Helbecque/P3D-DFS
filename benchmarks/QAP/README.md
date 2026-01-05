# The Quadratic Assignment problem

### Formulation

Given a set of $n$ facilities, characterized by a flow matrix $F=(f_{ij})$, and
$n$ locations, described by a distance matrix $\mathbb{D}=(d_{ij})$, the objective
is to find a permutation $\pi \in S_n$ that minimizes the total cost function:

$$\min_{\pi}\quad \sum_{i=0}^{n-1}\sum_{j=0}^{n-1}f_{ij}d_{\pi(i)\pi(j)},$$

where $S_n$ denotes the set of all bijective mappings from $n$ facilities to $n$
locations.

### Configuration options

```
./main_qap.out {...}
```

where the available options are:
- **`--inst`**: file(s) containing the instance data
  - `filename`: QAP instance where `filename` contains the flow and distance
  matrices formatted as follows:
  ```
  size

  flow matrix (delimited with spaces)

  distance matrix (delimited with spaces)
  ```
  File must be placed in `./instances/data_QAP` folder.

  - `filename1,filename2`: Qubit allocation instance where `filename1` and `filename2`
  contain the interaction frequency matrix and the coupling distance matrix,
  respectively, both formatted as follows:
  ```
  size

  matrix (delimited with spaces)
  ```
  Files must be placed in `./instances/data_QubitAlloc/inter` and
  `./instances/data_QubitAlloc/dist` folders, respectively.

- **`--itmax`**: maximum number of bounding iterations (only for `hhb` bound)
  - any positive integer (`10` by default)

- **`--lb`**: lower bound function
  - `glb`: Gilmore-Lawler bound [1] (default)
  - `hhb`: Hightower-Hahn bound [2]

- **`--ub`**: initial upper bound (UB)
  - `heuristic`: initialize the UB using a greedy heuristic (default)
  - `{NUM}`: initialize the UB to the given number

### References

1. Y. Li, P. M. Pardalos, K. G. Ramakrishnan, and M. G. C. Resende. (1994) Lower bounds for the quadratic assignment problem. *Annals of Operations Research*, 50:387-410. DOI: [10.1007/BF02085649](https://doi.org/10.1007/BF02085649).
2. P. Hahn and T. Grant. (1998) Lower Bounds for the Quadratic Assignment Problem Based upon a Dual Formulation. *Operations Research*, 46(6):912-922. DOI: [10.1287/opre.46.6.912](https://doi.org/10.1287/opre.46.6.912).
