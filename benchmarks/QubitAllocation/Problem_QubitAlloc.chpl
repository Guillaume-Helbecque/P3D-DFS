use IO;
use List;
use CTypes;

use Problem;

config param sizeMax: int = 27;

class Problem_QubitAlloc : Problem
{
  var N: int;
  var dom: domain(2);
  var D: [dom] c_int;
  var n: int;
  var F: [dom] c_int;

  var priority: [0..<sizeMax] c_int;

  proc init(filenameInter, filenameDist): void
  {
    init this;

    var f = open(filenameDist, ioMode.r);
    var channel = f.reader(locking=false);

    this.N = channel.read(int);
    this.dom = {0..<this.N, 0..<this.N};
    channel.read(this.D);

    channel.close();
    f.close();

    f = open(filenameInter, ioMode.r);
    channel = f.reader(locking=false);

    this.n = channel.read(int);
    assert(this.n <= this.N);

    for i in 0..<this.n {
      for j in 0..<this.n {
        this.F[i, j] = channel.read(c_int);
      }
    }

    channel.close();
    f.close();

    Prioritization(this.F, this.n, this.N);
    var min_cost = GreedyAllocation(this.D, this.F, this.priority, this.n, this.N);
  }

  proc Prioritization(F, n: int, N: int)
  {
    var sF: [0..<N] c_int;

    for i in 0..<N do
      sF[i] = (+ reduce F[i, 0..<n]);

    var min_inter, min_inter_index: c_int;

    for i in 0..<N
    {
      min_inter = sF[0];
      min_inter_index = 0;

      for j in 1..<N
      {
        if (sF[j] < min_inter)
        {
          min_inter = sF[j];
          min_inter_index = j:c_int;
        }
      }

      this.priority[N-1-i] = min_inter_index;

      sF[min_inter_index] = max(c_int);

      for j in 0..<N
      {
        if (sF[j] != max(c_int)) then
          sF[j] -= F[j, min_inter_index];
      }
    }
  }

  proc GreedyAllocation(const D, const F, const priority, n, N)
  {
    var route_cost = max(c_int);

    var l_min: c_int = 0;
    var k, i: c_int;
    var route_cost_temp, cost_incre, min_cost_incre: c_int;

    for j in 0..<N
    {
      var alloc_temp: [0..<sizeMax] c_int = -1;
      var available: [0..<N] bool = true;

      alloc_temp[priority[0]] = j:c_int;
      available[j] = false;

      // for each logical qubit (after the first one)
      for p in 1..<n
      {
        k = priority[p];

        min_cost_incre = max(c_int);

        // find physical qubit with least increasing route cost
        for l in 0..<N
        {
          if (available[l])
          {
            cost_incre = 0;
            for q in 0..<p
            {
              i = priority[q];
              cost_incre += F[i, k] * D[alloc_temp[i], l];
            }

            if (cost_incre < min_cost_incre)
            {
              l_min = l:c_int;
              min_cost_incre = cost_incre;
            }
          }
        }

        alloc_temp[k] = l_min;
        available[l_min] = false;
      }

      route_cost_temp = ObjectiveFunction(alloc_temp, D, F, n);

      if (route_cost_temp < route_cost) then
        route_cost = route_cost_temp;
    }

    return route_cost;
  }

  proc ObjectiveFunction(const mapping, const D, const F, n)
  {
    var route_cost: c_int = 0;

    for i in 0..<n
    {
       for j in i..<n
       {
           route_cost += F[i, j] * D[mapping[i], mapping[j]];
       }
    }

    return 2*route_cost;
  }

  override proc copy()
  {
    return new Problem_QubitAlloc();
  }

  override proc decompose(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
    ref max_depth: int, ref best: int, lock: sync bool, ref best_task: int): list(?)
  {
    var children: list(Node);
    // TODO
    return children;
  }

  override proc getInitBound(): int
  {
    return 0;
  }

  override proc help_message(): void
  {
    writeln("\n  Qubit Allocation Problem Parameters:\n");
  }

} // end class
