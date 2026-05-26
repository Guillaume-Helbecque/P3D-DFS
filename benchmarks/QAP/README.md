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

- **`--itmax`**: maximum number of bounding iterations (only for `rlt1`, `rlt2`, `qpb` bounds)
  - any positive integer (LB-specific defaults: `25` for `rlt1`/`rlt2`, `15` for `qpb`)

- **`--tol`**: relative tolerance of the stopping criterion (only for `rlt1`, `rlt2`, `qpb` bounds)
  - any positive real (LB-specific defaults: `1e-6` for `rlt1`/`rlt2`, `1e-5` for `qpb`)

- **`--lb`**: lower bound function
  - `glb`: Gilmore-Lawler bound [1] (default)
  - `iglb`: Improved Gilmore-Lawler bound [4]
  - `evb`: Eigenvalue-based bound [5]
  - `rlt1`: Reformulation-Linearization Technique of rank 1 [2]
  - `rlt2`: Reformulation-Linearization Technique of rank 2 [3]
  - `qpb`: Quadratic Programming Bound via Frank-Wolfe on the Birkhoff polytope
    with SDD dual [6]

- **`--ub`**: initial upper bound (UB)
  - `heuristic`: initialize the UB using a greedy heuristic (default)
  - `{NUM}`: initialize the UB to the given number

**Note:** `evb` and `qpb` bounds require the Eigen C++ template library.
Eigen is automatically downloaded during the build process.

### References

1. P. Gilmore. (1962) Optimal and Suboptimal Algorithms for the Quadratic Assignment Problem. *Journal of the Society for Industrial and Applied Mathematics*, 10(2):305-313. DOI: [10.1137/0110022](https://doi.org/10.1137/0110022).
2. P. Hahn and T. Grant. (1998) Lower Bounds for the Quadratic Assignment Problem Based upon a Dual Formulation. *Operations Research*, 46(6):912-922. DOI: [10.1287/opre.46.6.912](https://doi.org/10.1287/opre.46.6.912).
3. P. Hahn, W. Hightower, T. Johnson, M. Guignard-Spielberg, and C. Roucairol. (1998) A Lower Bound for the Quadratic Assignment Problem Based on a Level-2 Reformulation-Linearization Technique. ResearchGate. URL: [https://www.researchgate.net/publication/277286468_Lower_Bounds_for_the_Quadratic_Assignment_Problem_Based_Upon_a_Dual_Formulation](https://www.researchgate.net/publication/277286468_Lower_Bounds_for_the_Quadratic_Assignment_Problem_Based_Upon_a_Dual_Formulation).
4. P.M. Pardalos, K.G. Ramakrishnan, M.G.C. Resende, and Y. Li. (1997) Implementation of a Variance Reduction-Based Lower Bound in a Branch-and-Bound Algorithm for the Quadratic Assignment Problem. *SIAM Journal on Optimization*, 7(1):280-294. DOI: [10.1137/S1052623494273393](https://doi.org/10.1137/S1052623494273393).
5. S.W. Hadley, F. Rendl, and H. Wolkowicz. (1992) A New Lower Bound via Projection for the Quadratic Assignment Problem. *Mathematics of Operations Research*, 17(3):727-739. DOI: [10.1287/moor.17.3.727](https://doi.org/10.1287/moor.17.3.727).
6. K.M. Anstreicher and N.W. Brixius. (2001) A new bound for the quadratic assignment problem based on convex quadratic programming. *Mathematical Programming*, 89(3):341-357. DOI: [10.1007/PL00011402](https://doi.org/10.1007/PL00011402).
