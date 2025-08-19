use IO;
use List;
use CTypes;

use Util;
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

  proc ckmin(ref a, const ref b)
  {
    if (b < a) {
      a = b;
      return true;
    }

    return false;
  }

  proc Hungarian(ref C, i0, j0, n)
  {
    var w, j_cur, j_next: int;

    const inf: c_int = max(c_int) / 2;

    // job[j] = worker assigned to job j, or -1 if unassigned
    var job: [0..n] c_int = -1;

    // yw[w] is the potential for worker w
    // yj[j] is the potential for job j
    var yw: [0..<n] c_int;
    var yj: [0..n] c_int;

    // main Hungarian algorithm
    for w_cur in 0..<n
    {
      j_cur = n;
      job[j_cur] = w_cur:c_int;

      var min_to: [0..n] c_int = inf;
      var prv: [0..n] c_int = -1;
      var in_Z: [0..n] bool = false;

      while (job[j_cur] != -1)
      {
        in_Z[j_cur] = true;
        w = job[j_cur];
        var delta = inf;
        j_next = 0;

        for j in 0..<n
        {
          if (!in_Z[j])
          {
            // reduced cost = C[w][j] - yw[w] - yj[j]
            var cur_cost = C[idx4D(i0, j0, w, j, n)] - yw[w] - yj[j];

            if (ckmin(min_to[j], cur_cost)) then
              prv[j] = j_cur:c_int;
            if (ckmin(delta, min_to[j])) then
              j_next = j;
          }
        }

        // update potentials
        for j in 0..n
        {
          if (in_Z[j])
          {
            yw[job[j]] += delta;
            yj[j] -= delta;
          }
          else
          {
            min_to[j] -= delta;
          }
        }

        j_cur = j_next;
      }

      // update worker assignment along the found augmenting path
      while (j_cur != n) {
        var j = prv[j_cur];
        job[j_cur] = job[j];
        j_cur = j;
      }
    }

    // compute total cost
    var total_cost = 0;

    // for j in [0..n-1], job[j] is the worker assigned to job j
    for j in 0..<n
    {
      if (job[j] != -1) then
        total_cost += C[idx4D(i0, j0, job[j], j, n)];
    }

    // OPTIONAL: Reflecting the "reduced costs" after the Hungarian
    // algorithm by applying the final potentials:
    for w in 0..<n
    {
      for j in 0..<n
      {
        if (C[idx4D(i0, j0, w, j, n)] < inf)
        {
          // subtract the final potentials from the original cost
          C[idx4D(i0, j0, w, j, n)] = C[idx4D(i0, j0, w, j, n)] - yw[w] - yj[j];
        }
      }
    }

    return total_cost;
  }

  proc distributeLeader(ref C, ref L, n)
  {
    /* vector<int>& C = this -> costs;
    vector<int>& L = this -> leader;
    const int n = this -> size; */

    var leader_cost_div, leader_cost_rem, val: int;
    var leader_cost: c_int;

    if (n == 1)
    {
      C[0] = 0:c_int;
      L[0] = 0:c_int;

      return;
    }

    for i in 0..<n
    {
      for j in 0..<n
      {
        leader_cost = L[i*n + j];

        C[idx4D(i, j, i, j, n)] = 0:c_int;
        L[i*n + j] = 0:c_int;

        if (leader_cost == 0)
        {
          continue;
        }

        leader_cost_div = leader_cost / (n - 1);
        leader_cost_rem = leader_cost % (n - 1);

        for k in 0..<n
        {
          if (k == i) then
            continue;

          val = leader_cost_div + (k < leader_cost_rem || (k == leader_cost_rem && i < k));

          for l in 0..<n
          {
            if (l != j) then
              C[idx4D(i, j, k, l, n)] += val:c_int;
          }
        }
      }
    }
  }

  proc halveComplementary(ref C, n)
  {
    /* vector<int>& C = this -> costs;
    const int n = this -> size; */

    var cost_sum: c_int;

    for i in 0..<n
    {
      for j in 0..<n
      {
        for k in i..<n
        {
          for l in 0..<n
          {
            if ((k != i) && (l != j))
            {
              cost_sum = C[idx4D(i, j, k, l, n)] + C[idx4D(k, l, i, j, n)];
              C[idx4D(i, j, k, l, n)] = cost_sum / 2;
              C[idx4D(k, l, i, j, n)] = cost_sum / 2;

              if (cost_sum % 2 == 1)
              {
                if ((i + j + k + l) % 2 == 0) then // total index parity for balance
                  C[idx4D(i, j, k, l, n)] += 1;
                else
                  C[idx4D(k, l, i, j, n)] += 1;
              }
            }
          }
        }
      }
    }
  }

  proc bound(ref node, it_max, min_cost)
  {
    /* auto t0 = std::chrono::high_resolution_clock::now(); */

    ref lb = node.lower_bound;
    ref C = node.costs;
    ref L = node.leader;
    const m = node.size;
    /* CostMatrix& CM = this->costMatrix;

    const int m = CM.get_size();

    assert(m > 0 && "Error: Cannot bound problem of size 0.");

    vector<int>& C = CM.get_costs();
    vector<int>& L = CM.get_leader(); */

    var cost, incre: int;

    var it = 0;

    while (it < it_max && lb <= min_cost)
    {
      it += 1;

      distributeLeader(C, L, m);
      halveComplementary(C, m);

      // apply Hungarian algorithm to each sub-matrix
      for i in 0..<m
      {
        for j in 0..<m
        {
          cost = Hungarian(C, i, j, m);

          L[i*m + j] += cost:c_int;
        }
      }

      // apply Hungarian algorithm to the leader matrix
      incre = Hungarian(L, 0, 0, m);

      if (incre == 0) then
        break;

      lb += incre;
    }

    /* auto t1 = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> delta = t1 - t0;
    rt += delta.count(); */

    return lb;
  }

  override proc decompose(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
    ref max_depth: int, ref best: int, lock: sync bool, ref best_task: int): list(?)
  {
    var children: list(Node);
    var child = new Node(parent);

    var lb = bound(child, 10, max(c_int));
    writeln(child.costs);
    writeln("\n", lb);

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
