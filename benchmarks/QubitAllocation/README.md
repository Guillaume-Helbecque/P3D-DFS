# The Qubit Allocation problem

### Formulation

Given a quantum circuit involving $n$ logical qubits, characterized by an
interaction frequency matrix $F=(f_{ij})$, and a quantum device with $N \ge n$ physical
qubits, described by a coupling distance matrix $\mathbb{D}=(d_{ij})$, the objective is to
find a partial permutation $\pi \in S^N_n$ that minimizes the route cost function:

$$\min_{\pi}\quad 2 \sum_{i=0}^{N-1}\sum_{j=i+1}^{N-1}f_{ij}d_{\pi(i)\pi(j)},$$

where $S^N_n$ denotes the set of all injective mappings (partial permutations) from
$n$ logical qubits to $N$ physical qubits.

### Configuration options

```
./main_qubitAlloc.out {...}
```

where the available options are:
- **`--inter`**: file containing the interaction frequency matrix
  - must be placed in the `./instances/inter` folder and formatted as follows:
  ```
  n

  matrix (delimited with spaces)
  ```

- **`--dist`**: file containing the coupling distance matrix
  - must be placed in the `./instances/dist` folder and formatted as follows:
  ```
  N

  matrix (delimited with spaces)
  ```

- **`--itmax`**: maximum number of bounding iterations
  - any positive integer (`10` by default)

- **`--ub`**: initial upper bound (UB)
  - `heuristic`: initialize the UB using a greedy heuristic (default)
  - `{NUM}`: initialize the UB to the given number
