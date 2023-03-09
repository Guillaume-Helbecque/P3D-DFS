# The 0/1-Knapsack problem

Given a set of $N$ items, each item $i$ having a weight ${w_i}$ and a profit ${p_i}$, the problem is to determine which items to include in the collection so that the total weight is less than or equal to a given limit $W$ and the total profit is as large as possible.

### Launch & Command-line parameters

The instance to solve must be contained in a file according to the format below, and the latter must be placed in the `./instances` folder:
```
N W
list of weights (delimited with spaces)
list of profits (delimited with spaces)
```
Then, the launch is done using:
```
./main_knapsack.o --name=file_name
```
where:
- `file_name` (`str`): name of the file containing the data.

By default, `default.txt` is solved:
```
15  750
70  73  77  80  82  87  90  94  98  106 110 113 115 118 120
135 139 149 150 156 163 173 184 192 201 210 214 221 229 240
```
