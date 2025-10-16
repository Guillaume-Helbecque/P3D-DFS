# The Quadratic Assignment problem

### Formulation

Given a quantum circuit involving $n$ logical qubits, characterized by an
interaction frequency matrix $F=(f_{ij})$, and a quantum device with $N \ge n$ physical
qubits, described by a coupling distance matrix $\mathbb{D}=(d_{ij})$, the objective is to
find a partial permutation $\pi \in S^N_n$ that minimizes the route cost function:

$$\min_{\pi}\quad 2 \sum_{i=0}^{N-1}\sum_{j=i+1}^{N-1}f_{ij}d_{\pi(i)\pi(j)},$$

where $S^N_n$ denotes the set of all injective mappings (partial permutations) from
$n$ logical qubits to $N$ physical qubits.

### Configuration options

At compilation, it is possible to choose the bounding function used using:

```
make main_qap.out QAP_BOUND={...}
```

where the available options are:
  - `glb`: Gilmore-Lawler bound [1] (default)
  - `hhb`: Hightower-Hahn bound [2]

Then, the executable supports other options, as detailed below.

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

- **`--ub`**: initial upper bound (UB)
  - `heuristic`: initialize the UB using a greedy heuristic (default)
  - `{NUM}`: initialize the UB to the given number

### References

1. Y. Li, P. M. Pardalos, K. G. Ramakrishnan, and M. G. C. Resende. (1994) Lower bounds for the quadratic assignment problem. *Annals of Operations Research*, 50:387-410. DOI: [10.1007/BF02085649](https://doi.org/10.1007/BF02085649).
2. P. Hahn and T. Grant. (1998) Lower Bounds for the Quadratic Assignment Problem Based upon a Dual Formulation. *Operations Research*, 46(6):912-922. DOI: [10.1287/opre.46.6.912](https://doi.org/10.1287/opre.46.6.912).
