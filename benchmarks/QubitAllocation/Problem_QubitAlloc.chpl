use IO;
use List;
use CTypes;

use Util;
use Problem;

config param sizeMax: int(32) = 27;

class Problem_QubitAlloc : Problem
{
  var filenameInter: string;
  var filenameDist: string;
  var N: int(32);
  var dom: domain(2, idxType = int(32));
  var D: [dom] int(32);
  var n: int(32);
  var F: [dom] int(32);

  var priority: [0..<sizeMax] int(32);

  var it_max: int(32);

  var ub_init: string;
  var initUB: int(32);

  proc init(filenameInter, filenameDist, itmax, ub): void
  {
    this.filenameInter = filenameInter;
    this.filenameDist = filenameDist;

    init this;

    var f = open("./benchmarks/QubitAllocation/instances/dist/" + filenameDist + ".csv", ioMode.r);
    var channel = f.reader(locking=false);

    channel.read(this.N);
    this.dom = {0..<this.N, 0..<this.N};
    channel.read(this.D);

    channel.close();
    f.close();

    f = open("./benchmarks/QubitAllocation/instances/inter/" + filenameInter + ".csv", ioMode.r);
    channel = f.reader(locking=false);

    channel.read(this.n);
    // TODO: add an error message
    assert(this.n <= this.N);

    for i in 0..<this.n {
      for j in 0..<this.n {
        this.F[i, j] = channel.read(int(32));
      }
    }

    channel.close();
    f.close();

    Prioritization(this.F, this.n, this.N);
    this.it_max = itmax;

    this.ub_init = ub;
    if (ub == "heuristic") then this.initUB = GreedyAllocation(this.D, this.F, this.priority, this.n, this.N);
    else {
      try! this.initUB = ub:int(32);

      // NOTE: If `ub` cannot be cast into `int(32)`, an errow is thrown. For now, we cannot
      // manage it as only catch-less try! statements are allowed in initializers.
      // Ideally, we'd like to do this:

      /* try {
        this.initUB = ub:int(32);
      } catch {
        halt("Error - Unsupported initial upper bound");
      } */
    }
  }

  proc init(const filenameInter: string, const filenameDist: string,
    const N, const dom, const D, const n, const F, const priority,
    const it_max, const ub_init, const initUB): void
  {
    this.filenameInter = filenameInter;
    this.filenameDist = filenameDist;
    this.N = N;
    this.dom = dom;
    this.D = D;
    this.n = n;
    this.F = F;
    this.priority = priority;
    this.it_max = it_max;
    this.ub_init = ub_init;
    this.initUB = initUB;
  }

  proc Prioritization(const ref F, n: int(32), N: int(32))
  {
    var sF: [0..<N] int(32);

    for i in 0..<N do
      sF[i] = (+ reduce F[i, 0..<n]);

    var min_inter, min_inter_index: int(32);

    for i in 0..<N {
      min_inter = sF[0];
      min_inter_index = 0;

      for j in 1..<N {
        if (sF[j] < min_inter) {
          min_inter = sF[j];
          min_inter_index = j:int(32);
        }
      }

      this.priority[N-1-i] = min_inter_index;

      sF[min_inter_index] = INF;

      for j in 0..<N {
        if (sF[j] != INF) then
          sF[j] -= F[j, min_inter_index];
      }
    }
  }

  proc GreedyAllocation(const ref D, const ref F, const ref priority, n, N)
  {
    var route_cost = INF;

    var l_min, k, i: int(32);
    var route_cost_temp, cost_incre, min_cost_incre: int(32);

    for j in 0..<N {
      var alloc_temp: [0..<sizeMax] int(32) = -1;
      var available: [0..<N] bool = true;

      alloc_temp[priority[0]] = j:int(32);
      available[j] = false;

      // for each logical qubit (after the first one)
      for p in 1..<n {
        k = priority[p];

        min_cost_incre = INF;

        // find physical qubit with least increasing route cost
        for l in 0..<N {
          if (available[l]) {
            cost_incre = 0;
            for q in 0..<p {
              i = priority[q];
              cost_incre += F[i, k] * D[alloc_temp[i], l];
            }

            if (cost_incre < min_cost_incre) {
              l_min = l:int(32);
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

  proc ObjectiveFunction(const mapping, const ref D, const ref F, n)
  {
    var route_cost: int(32);

    for i in 0..<n {
       for j in i..<n {
          route_cost += F[i, j] * D[mapping[i], mapping[j]];
       }
    }

    return 2*route_cost;
  }

  override proc copy()
  {
    /* return new Problem_QubitAlloc(this.filenameInter, this.filenameDist,
      this.N, this.dom, this.D, this.n, this.F, this.priority,
      this.it_max, this.ub_init, this.initUB); */
    return new Problem_QubitAlloc(this.filenameInter, this.filenameDist, this.it_max, this.ub_init);
  }

  proc Hungarian(ref C, i0, j0, n)
  {
    var w, j_cur, j_next: int(32);

    // job[j] = worker assigned to job j, or -1 if unassigned
    var job = allocate(int(32), n+1);
    for i in 0..n do job[i] = -1:int(32);

    // yw[w] is the potential for worker w
    // yj[j] is the potential for job j
    var yw = allocate(int(32), n);
    for i in 0..<n do yw[i] = 0:int(32);
    var yj = allocate(int(32), n+1);
    for i in 0..n do yj[i] = 0:int(32);

    // main Hungarian algorithm
    for w_cur in 0..<n {
      j_cur = n;
      job[j_cur] = w_cur:int(32);

      var min_to = allocate(int(32), n+1);
      for i in 0..n do min_to[i] = INFD2;
      var prv = allocate(int(32), n+1);
      for i in 0..n do prv[i] = -1:int(32);
      var in_Z = allocate(bool, n+1);
      for i in 0..n do in_Z[i] = false;

      while (job[j_cur] != -1) {
        in_Z[j_cur] = true;
        w = job[j_cur];
        var delta = INFD2;
        j_next = 0;

        for j in 0..<n {
          if (!in_Z[j]) {
            // reduced cost = C[w][j] - yw[w] - yj[j]
            var cur_cost = C[idx4D(i0, j0, w, j, n)] - yw[w] - yj[j];

            if (ckmin(min_to[j], cur_cost)) then
              prv[j] = j_cur;
            if (ckmin(delta, min_to[j])) then
              j_next = j;
          }
        }

        // update potentials
        for j in 0..n {
          if (in_Z[j]) {
            yw[job[j]] += delta;
            yj[j] -= delta;
          }
          else {
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

      deallocate(min_to);
      deallocate(prv);
      deallocate(in_Z);
    }

    // compute total cost
    var total_cost: int(32);

    // for j in [0..n-1], job[j] is the worker assigned to job j
    for j in 0..<n {
      if (job[j] != -1) then
        total_cost += C[idx4D(i0, j0, job[j], j, n)];
    }

    // OPTIONAL: Reflecting the "reduced costs" after the Hungarian
    // algorithm by applying the final potentials:
    for w in 0..<n {
      for j in 0..<n {
        if (C[idx4D(i0, j0, w, j, n)] < INFD2) {
          // subtract the final potentials from the original cost
          C[idx4D(i0, j0, w, j, n)] = C[idx4D(i0, j0, w, j, n)] - yw[w] - yj[j];
        }
      }
    }

    deallocate(job);
    deallocate(yw);
    deallocate(yj);

    return total_cost;
  }

  proc distributeLeader(ref C, ref L, n)
  {
    var leader_cost, leader_cost_div, leader_cost_rem, val: int(32);

    if (n == 1) {
      C[0] = 0:int(32);
      L[0] = 0:int(32);

      return;
    }

    for i in 0..<n {
      for j in 0..<n {
        leader_cost = L[i*n + j];

        C[idx4D(i, j, i, j, n)] = 0:int(32);
        L[i*n + j] = 0:int(32);

        if (leader_cost == 0) {
          continue;
        }

        leader_cost_div = leader_cost / (n - 1);
        leader_cost_rem = leader_cost % (n - 1);

        for k in 0..<n {
          if (k == i) then
            continue;

          val = leader_cost_div + (k < leader_cost_rem || (k == leader_cost_rem && i < k));

          for l in 0..<n {
            if (l != j) then
              C[idx4D(i, j, k, l, n)] += val;
          }
        }
      }
    }
  }

  proc halveComplementary(ref C, n)
  {
    var cost_sum: int(32);

    for i in 0..<n {
      for j in 0..<n {
        for k in i..<n {
          for l in 0..<n {
            if ((k != i) && (l != j)) {
              cost_sum = C[idx4D(i, j, k, l, n)] + C[idx4D(k, l, i, j, n)];
              C[idx4D(i, j, k, l, n)] = cost_sum / 2;
              C[idx4D(k, l, i, j, n)] = cost_sum / 2;

              if (cost_sum % 2 == 1) {
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

  proc bound(ref node, best)
  {
    ref lb = node.lower_bound;
    ref C = node.costs;
    ref L = node.leader;
    const m = node.size;

    var cost, incre: int(32);

    var it = 0;

    while (it < this.it_max && lb <= best) {
      it += 1;

      distributeLeader(C, L, m);
      halveComplementary(C, m);

      // apply Hungarian algorithm to each sub-matrix
      for i in 0..<m {
        for j in 0..<m {
          cost = Hungarian(C, i, j, m);

          L[i*m + j] += cost;
        }
      }

      // apply Hungarian algorithm to the leader matrix
      incre = Hungarian(L, 0, 0, m);

      if (incre == 0) then
        break;

      lb += incre;
    }

    return lb;
  }

  proc reduceNode(type Node, parent, i, j, k, l, lb_new)
  {
    var child = new Node(parent);
    child.depth += 1;

    // assign q_i to P_j
    child.mapping[i] = j;

    const n = parent.size;
    const m = n - 1;
    child.size -= 1;

    /* assert(n > 0 && "Cannot reduce problem of size 0.");
    assert(std::min(i, j) >= 0 && std::max(i, j) < n && "Invalid reduction indices."); */

    var L_copy = parent.leader;

    child.domCost = {0..<m**4};
    child.domLeader = {0..<m**2};

    var x2, y2, p2, q2: int(32);

    // Updating the leader
    for x in 0..<n {
      if (x == k) then
        continue;

      for y in 0..<n {
        if (y != l) {
          L_copy[x*n + y] += (parent.costs[idx4D(x, y, k, l, n)] + parent.costs[idx4D(k, l, x, y, n)]);
        }
      }
    }

    // reducing the matrix
    x2 = 0;
    for x in 0..<n {
      if (x == k) then
        continue;

      y2 = 0;
      for y in 0..<n {
        if (y == l) then
          continue;

        // copy C_xy into C_x2y2
        p2 = 0;
        for p in 0..<n {
          if (p == k) then
            continue;

          q2 = 0;
          for q in 0..<n {
            if (q == l) then
              continue;

            child.costs[idx4D(x2, y2, p2, q2, m)] = parent.costs[idx4D(x, y, p, q, n)];
            q2 += 1;
          }
          p2 += 1;
        }

        child.leader[x2*m + y2] = L_copy[x*n + y];
        y2 += 1;
      }
      x2 += 1;
    }

    child.available[j] = false;

    child.lower_bound = lb_new;

    return child;
  }

  override proc decompose(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
    ref max_depth: int, ref best: int, lock: sync bool, ref best_task: int): list(?)
  {
    var children: list(Node);

    var depth = parent.depth;

    if (parent.depth == this.n) {
      const eval = ObjectiveFunction(parent.mapping, this.D, this.F, this.n);

      if (eval < best_task) {
        best_task = eval;
        lock.readFE();
        if eval < best then best = eval;
        else best_task = best;
        lock.writeEF(true);
      }

      num_sol += 1;
    }
    else {
      var i = this.priority[depth];

      // local index of q_i in the cost matrix
      var k = localLogicalQubitIndex(parent.mapping, i);

      for j in 0..(this.N - 1) by -1 {
        if (!parent.available[j]) then continue; // skip if not available

        // next available physical qubit
        var l = localPhysicalQubitIndex(parent.available, j);

        // increment lower bound
        var incre = parent.leader[k*(this.N - depth) + l];
        var lb_new = parent.lower_bound + incre;

        // prune
        if (lb_new > best) {
          continue;
        }

        var child = reduceNode(Node, parent, i, j, k, l, lb_new);

        if (child.depth < this.n) {
          var lb = bound(child, best_task);
          if (lb <= best_task) {
            children.pushBack(child);
            tree_loc += 1;
          }
        }
        else {
          children.pushBack(child);
          tree_loc += 1;
        }
      }
    }

    return children;
  }

  override proc print_settings(): void
  {
    writeln("\n=================================================");
    writeln("Circuit: ", this.filenameInter);
    writeln("Device: ", this.filenameDist);
    writeln("Number of logical qubits: ", this.n);
    writeln("Number of physical qubits: ", this.N);
    writeln("Max bounding iterations: ", this.it_max);
    writeln("Initial upper bound: ", this.initUB);
    writeln("=================================================");
  }

  override proc print_results(const subNodeExplored, const subSolExplored,
    const subDepthReached, const best: int, const elapsedTime: real): void
  {
    var treeSize, nbSol: int;

    if (isArray(subNodeExplored) && isArray(subSolExplored)) {
      treeSize = (+ reduce subNodeExplored);
      nbSol = (+ reduce subSolExplored);
    } else { // if not array, then int
      treeSize = subNodeExplored;
      nbSol = subSolExplored;
    }

    var par_mode: string = if (numLocales == 1) then "tasks" else "locales";

    writeln("\n=================================================");
    writeln("Size of the explored tree: ", treeSize);
    /* writeln("Size of the explored tree per locale: ", sizePerLocale); */
    if isArray(subNodeExplored) {
      writeln("% of the explored tree per ", par_mode, ": ", 100 * subNodeExplored:real / treeSize:real);
    }
    writeln("Number of explored solutions: ", nbSol);
    /* writeln("Number of explored solutions per locale: ", numSolPerLocale); */
    const is_better = if (best < this.initUB) then " (improved)"
                                              else " (not improved)";
    writeln("Optimal allocation: ", best, is_better);
    writeln("Elapsed time: ", elapsedTime, " [s]");
    writeln("=================================================\n");
  }

  override proc getInitBound(): int
  {
    return this.initUB;
  }

  override proc output_filepath(): string
  {
    return "./chpl_qubitAlloc.txt";
  }

  override proc help_message(): void
  {
    writeln("\n  Qubit Allocation Problem Parameters:\n");
    writeln("   --dist   str  interaction frequency matrix file name");
    writeln("   --inter  str  coupling distance matrix file name");
    writeln("   --itmax  int  maximum number of bounding iterations (optional, default: 10)\n");
  }

} // end class
