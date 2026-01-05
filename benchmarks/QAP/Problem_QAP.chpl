module Problem_QAP
{
  use List;
  use Sort;
  use CTypes;

  use Util;
  use Problem;
  use Instances;

  const allowedLowerBounds = ["glb", "hhb"];

  class Problem_QAP : Problem
  {
    var filename: string;
    var benchmark: string;
    var n: int(32);
    var N: int(32);
    var F: [0..<N, 0..<N] int(32);
    var D: [0..<N, 0..<N] int(32);

    var priority_fac: [0..<n] int(32);
    var priority_loc: [0..<N] int(32);

    var it_max: int(32);

    var lb_name: string;

    var ub_init: string;
    var initUB: int;

    proc init(filename, itmax, lb, ub): void
    {
      this.filename = filename;
      var getFilenames = filename.split(",");

      var inst = new Instance();
      if (getFilenames.size == 1) {
        this.benchmark = "qap";
        inst = new Instance_QAP(getFilenames[0]);
      }
      else if (getFilenames.size == 2) {
        this.benchmark = "qubitAlloc";
        inst = new Instance_QubitAlloc(getFilenames[0], getFilenames[1]);
      }
      else halt("Error - Unknown instance");

      this.n = inst.get_nb_facilities();
      this.N = inst.get_nb_locations();

      init this;

      inst.get_flow(this.F);
      inst.get_distance(this.D);

      Prioritization(this.priority_fac, this.F, this.n, ascend = false);
      if this.benchmark == "qubitAlloc" then
        Prioritization_loc_connec(this.D, this.N);
      else
        Prioritization(this.priority_loc, this.D, this.N);

      this.it_max = itmax;

      if (allowedLowerBounds.find(lb) != -1) then this.lb_name = lb;
      else halt("Error - Unsupported lower bound");

      this.ub_init = ub;
      if (ub == "heuristic") then this.initUB = GreedyAllocation(this.D, this.F, this.priority_fac, this.n, this.N);
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

    proc init(const filename: string, const benchmark, const N, const D, const n,
      const F, const priority_fac, const priority_loc, const it_max, const lb_name,
      const ub_init, const initUB): void
    {
      this.filename = filename;
      this.benchmark = benchmark;
      this.n = n;
      this.N = N;
      this.F = F;
      this.D = D;
      this.priority_fac = priority_fac;
      this.priority_loc = priority_loc;
      this.it_max = it_max;
      this.lb_name = lb_name;
      this.ub_init = ub_init;
      this.initUB = initUB;
    }

    override proc copy()
    {
      return new Problem_QAP(this.filename, this.it_max, this.lb_name, this.ub_init);
    }

    proc RowwiseNumZeros(const ref D, const N)
    {
      var nzD: [0..#N] int(32);

      for i in 0..<N {
        for j in 0..<N {
          if !D[i, j] then
            nzD[i] += 1;
        }
      }

      return nzD;
    }

    proc Prioritization(ref priority, const ref F, n: int(32), ascend = true)
    {
      var sF: [0..<n] int(32);

      for i in 0..<n do
        sF[i] = (+ reduce F[i, 0..<n]);

      var min_inter, min_inter_index: int(32);

      for i in 0..<n {
        min_inter = sF[0];
        min_inter_index = 0;

        for j in 1..<n {
          if (sF[j] < min_inter) {
            min_inter = sF[j];
            min_inter_index = j;
          }
        }

        if ascend then
          priority[i] = min_inter_index;
        else
          priority[n-1-i] = min_inter_index;

        sF[min_inter_index] = INF32;

        for j in 0..<n {
          if (sF[j] != INF32) then
            sF[j] -= F[j, min_inter_index];
        }
      }
    }

    /* rank physical qubits (locations) based on their connectivity degree */
    proc Prioritization_loc_connec(const ref D, const N)
    {
      var nzD = RowwiseNumZeros(this.D, this.N);

      var min_connec, min_connec_index: int(32);

      for i in 0..<this.N {
        min_connec = nzD[0];
        min_connec_index = 0;

        for j in 1..<this.N {
          if (nzD[j] < min_connec) {
            min_connec = nzD[j];
            min_connec_index = j;
          }
        }

        this.priority_loc[i] = min_connec_index;

        nzD[min_connec_index] = INF32;
      }
    }

    proc GreedyAllocation(const ref D, const ref F, const ref priority, n, N)
    {
      var route_cost = INF;

      var l_min, k, i: int(32);
      var route_cost_temp, cost_incre, min_cost_incre: int;

      for j in 0..<N {
        var alloc_temp: [0..<n] int(32) = -1;
        var available: [0..<N] bool = true;

        alloc_temp[priority[0]] = j;
        available[j] = false;

        // for each logical qubit (after the first one)
        for p in 1..<n {
          k = priority[p];

          min_cost_incre = INF;

          // find physical qubit with least increasing route cost
          for l in 0..<N {
            if available[l] {
              cost_incre = 0;
              for q in 0..<p {
                i = priority[q];
                cost_incre += F[i, k] * D[alloc_temp[i], l];
              }

              if (cost_incre < min_cost_incre) {
                l_min = l;
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
      var route_cost: int;

      for i in 0..<n {
        if (mapping[i] == -1) then
          continue;

        for j in 0..<n {
          if (mapping[j] == -1) then
            continue;

          route_cost += F[i, j] * D[mapping[i], mapping[j]];
        }
      }

      return route_cost;
    }

    /*******************************************************
                      HIGHTOWER-HAHN BOUND
    *******************************************************/

    proc Hungarian_HHB(ref C, i0, j0, n)
    {
     var w, j_cur, j_next: int(32);

     // job[j] = worker assigned to job j, or -1 if unassigned
     var job = allocate(int(32), n+1);
     for i in 0..n do job[i] = -1;

     // yw[w] is the potential for worker w
     // yj[j] is the potential for job j
     var yw = allocate(int, n);
     for i in 0..<n do yw[i] = 0;
     var yj = allocate(int, n+1);
     for i in 0..n do yj[i] = 0;

     // main Hungarian algorithm
     for w_cur in 0..<n {
       j_cur = n;
       job[j_cur] = w_cur;

       var min_to = allocate(int, n+1);
       for i in 0..n do min_to[i] = INFD2;
       var prv = allocate(int(32), n+1);
       for i in 0..n do prv[i] = -1;
       var in_Z = allocate(bool, n+1);
       for i in 0..n do in_Z[i] = false;

       while (job[j_cur] != -1) {
         in_Z[j_cur] = true;
         w = job[j_cur];
         var delta = INFD2;
         j_next = 0;

         for j in 0..<n {
           if !in_Z[j] {
             // reduced cost = C[w][j] - yw[w] - yj[j]
             var cur_cost = C[idx4D(i0, j0, w, j, n)] - yw[w] - yj[j];

             if ckmin(min_to[j], cur_cost) then
               prv[j] = j_cur;
             if ckmin(delta, min_to[j]) then
               j_next = j;
           }
         }

         // update potentials
         for j in 0..n {
           if in_Z[j] {
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
     var total_cost: int;

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
      var leader_cost, leader_cost_div, leader_cost_rem, val: int;

      if (n == 1) {
        C[0] = 0;
        L[0] = 0;

        return;
      }

      for i in 0..<n {
        for j in 0..<n {
          leader_cost = L[i*n + j];

          C[idx4D(i, j, i, j, n)] = 0;
          L[i*n + j] = 0;

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
      var cost_sum: int;

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

    proc bound_HHB(ref node, best)
    {
      ref lb = node.lower_bound;
      ref C = node.costs;
      ref L = node.leader;
      const m = node.size;

      var cost, incre: int;

      var it = 0;

      while (it < this.it_max && lb <= best) {
        it += 1;

        distributeLeader(C, L, m);
        halveComplementary(C, m);

        // apply Hungarian algorithm to each sub-matrix
        for i in 0..<m {
          for j in 0..<m {
            cost = Hungarian_HHB(C, i, j, m);

            L[i*m + j] += cost;
          }
        }

        // apply Hungarian algorithm to the leader matrix
        incre = Hungarian_HHB(L, 0, 0, m);

        if (incre == 0) then
          break;

        lb += incre;
      }

      return lb;
    }

    proc decompose_HHB(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, ref best: int, lock: sync bool, ref best_task: int): list(?)
    {
      var children: list(Node);

      var depth = parent.depth;

      if (parent.depth == this.n) {
        const eval = ObjectiveFunction(parent.mapping, this.D, this.F, this.n);

        if (eval < best_task) {
          best_task = eval;
          lock.readFE();
          if eval <= best {
            best = eval;
            num_sol = 1;
          }
          else {
            best_task = best;
            num_sol = 0;
          }
          lock.writeEF(true);
        }
        else if (eval == best_task) {
          num_sol += 1;
        }
        else {
          tree_loc -= 1;
        }
      }
      else {
        local {
          var i = this.priority_fac[depth];

          // local index of q_i in the cost matrix
          var k = localLogicalQubitIndex(parent.mapping, i);

          for j0 in 0..<this.N by -1 {
            const j = this.priority_loc[j0];

            if !parent.available[j] then continue; // skip if not available

            // next available physical qubit
            var l = localPhysicalQubitIndex(parent.available, j);

            // increment lower bound
            var incre = parent.leader[k*(this.N - depth) + l];
            var lb_new = parent.lower_bound + incre;

            // prune
            if (lb_new > best_task) {
              continue;
            }

            var child = reduceNode(Node, parent, i, j, k, l, lb_new);

            if (child.depth < this.n) {
              var lb = bound_HHB(child, best_task);
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
      }

      return children;
    }

    /*******************************************************
                       GILMORE-LAWLER
    *******************************************************/

    proc Hungarian_GLB(const ref C, n, m)
    {
      var w, j_cur, j_next: int(32);

      // job[j] = worker assigned to job j, or -1 if unassigned
      var job = allocate(int(32), m+1);
      for i in 0..m do job[i] = -1;

      // yw[w] is the potential for worker w
      // yj[j] is the potential for job j
      var yw = allocate(int, n, clear=true);
      var yj = allocate(int, m+1, clear=true);

      // main Hungarian algorithm
      for w_cur in 0..<n {
        j_cur = m;                       // dummy job index
        job[j_cur] = w_cur;

        var min_to = allocate(int, m+1);
        for i in 0..m do min_to[i] = INFD2;
        var prv = allocate(int(32), m+1);
        for i in 0..m do prv[i] = -1;
        var in_Z = allocate(bool, m+1);
        for i in 0..m do in_Z[i] = false;

        while (job[j_cur] != -1) {
          in_Z[j_cur] = true;
          w = job[j_cur];
          var delta = INFD2;
          j_next = 0;

          for j in 0..<m {
            if !in_Z[j] {
              // reduced cost = C[w][j] - yw[w] - yj[j]
              var cur_cost = C[w*m + j] - yw[w] - yj[j];

              if ckmin(min_to[j], cur_cost) then
                prv[j] = j_cur;
              if ckmin(delta, min_to[j]) then
                j_next = j;
            }
          }

          // update potentials
          for j in 0..m {
            if in_Z[j] {
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
        while (j_cur != m) {
          var j = prv[j_cur];
          job[j_cur] = job[j];
          j_cur = j;
        }

        deallocate(min_to);
        deallocate(prv);
        deallocate(in_Z);
      }

      // compute total cost
      var total_cost: int;

      // for j in [0..m-1], job[j] is the worker assigned to job j
      for j in 0..<m {
        if (job[j] != -1) then
          total_cost += C[job[j]*m + j];
      }

      deallocate(job);
      deallocate(yw);
      deallocate(yj);

      return total_cost;
    }

    proc Assemble_LAP(ref L, const dp, const partial_mapping, const ref av)
    {
      var assigned_fac = allocate(int(32), dp);
      var unassigned_fac = allocate(int(32), this.n-dp);
      var assigned_loc = allocate(int(32), dp);
      var unassigned_loc = allocate(int(32), this.N-dp);
      var c1, c2, c3, c4: int(32) = 0;

      for i in 0..<this.n {
        if (partial_mapping[i] != -1) {
          assigned_fac[c1] = i;
          c1 += 1;
          assigned_loc[c3] = partial_mapping[i];
          c3 += 1;
        }
        else {
          unassigned_fac[c2] = i;
          c2 += 1;
        }
      }

      for i in 0..<this.N {
        if av[i] {
          unassigned_loc[c4] = i;
          c4 += 1;
        }
      }

      var u = this.n - dp;
      var r = this.N - dp;

      // Precompute sorted distances from each location k to other free locations
      var sortedDidx: [0..<r] [0..<(r-1)] int(32);

      for k_idx in 0..<r {
        var k = unassigned_loc[k_idx];

        // create temporary vector of {dist, l_idx} pairs
        var tmp: [0..<(r-1)] (int(32), int(32));
        var c5: int(32) = 0;

        for l_idx in 0..<r {
          if (k_idx == l_idx) then
            continue;

          var l = unassigned_loc[l_idx];
          tmp[c5] = (this.D[k, l], l_idx);
          c5 += 1;
        }

        // sort by distance (ascending)
        record AscendingComparator : keyComparator { }
        proc AscendingComparator.key(elt) { return elt(0); }
        var ascendingComparator: AscendingComparator;
        sort(tmp, comparator=ascendingComparator);

        for t in 0..<(r-1) do
          sortedDidx[k_idx][t] = tmp[t](0);
      }

      // Loop over unassigned facilities
      for i_idx in 0..<u {
        var i = unassigned_fac[i_idx];

        // extract flows from i to other unassigned facilities
        var flows: [0..<(u-1)] int(32);
        var c6: int(32) = 0;

        for j_idx in 0..<u {
          var j = unassigned_fac[j_idx];

          if (i == j) then
            continue;

          flows[c6] = this.F[i, j];
          c6 += 1;
        }

        // sort extracted flows (descending)
        sort(flows, comparator = new reverseComparator());

        // compute L[i_idx, k_idx] for each location k
        for k_idx in 0..<r {
          var k = unassigned_loc[k_idx];
          var cost: int;

          // unassigned–unassigned part: GLB pairing
          var pairs = min(u-1, r-1);
          for t in 0..<pairs {
            cost += flows[t]:int * sortedDidx[k_idx][t]:int;
          }

          // assigned–unassigned part (both directions)
          for a_idx in 0..<dp {
            var j = assigned_fac[a_idx];
            var l = partial_mapping[j];

            cost += this.F[i, j]:int * this.D[k, l]:int;
            cost += this.F[j, i]:int * this.D[l, k]:int;
          }

          L[i_idx*r + k_idx] = cost;
        }
      }

      deallocate(assigned_fac);
      deallocate(unassigned_fac);
      deallocate(assigned_loc);
      deallocate(unassigned_loc);
    }

    proc bound_GLB(const ref node)
    {
      const partial_mapping = node.mapping;
      const ref av = node.available;
      const dp = node.depth;

      var fixed_cost, remaining_lb: int;

      local {
        var L = allocate(int, (this.n - dp)*(this.N - dp), clear=true);

        Assemble_LAP(L, dp, partial_mapping, av);

        fixed_cost = ObjectiveFunction(partial_mapping, this.D, this.F, this.n);

        remaining_lb = Hungarian_GLB(L, this.n - dp, this.N - dp);

        deallocate(L);
      }

      return fixed_cost + remaining_lb;
    }

    proc decompose_GLB(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, ref best: int, lock: sync bool, ref best_task: int): list(?)
    {
      var children: list(Node);

      var depth = parent.depth;

      if (parent.depth == this.n) {
        const eval = ObjectiveFunction(parent.mapping, this.D, this.F, this.n);

        if (eval < best_task) {
          best_task = eval;
          lock.readFE();
          if eval <= best {
            best = eval;
            num_sol = 1;
          }
          else {
            best_task = best;
            num_sol = 0;
          }
          lock.writeEF(true);
        }
        else if (eval == best_task) {
          num_sol += 1;
        }
        else {
          tree_loc -= 1;
        }
      }
      else {
        var i = this.priority_fac[depth];

        for j0 in 0..<this.N by -1 {
          const j = this.priority_loc[j0];

          if !parent.available[j] then continue; // skip if not available

          var child = new Node(parent);
          child.depth += 1;
          child.mapping[i] = j;
          child.available[j] = false;

          if (child.depth < this.n) {
            var lb = bound_GLB(child);
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

    override proc decompose(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, ref best: int, lock: sync bool, ref best_task: int): list(?)
    {
      select this.lb_name {
        when "hhb" {
          return decompose_HHB(Node, parent, tree_loc, num_sol, max_depth, best, lock, best_task);
        }
        when "glb" {
          return decompose_GLB(Node, parent, tree_loc, num_sol, max_depth, best, lock, best_task);
        }
        otherwise {
          halt("DEADCODE");
        }
      }
    }

    override proc print_settings(): void
    {
      writeln("\n=================================================");
      if (this.benchmark == "qap") {
        writeln("QAP instance: ", this.filename);
        writeln("Number of locations: ", this.N);
      }
      else if (this.benchmark == "qubitAlloc") {
        var getFilenames = this.filename.split(",");
        writeln("Circuit: ", getFilenames[0]);
        writeln("Device: ", getFilenames[1]);
        writeln("Number of logical qubits: ", this.n);
        writeln("Number of physical qubits: ", this.N);
      }
      if (this.lb_name == "hhb") then
        writeln("Max bounding iterations: ", this.it_max);
      const heuristic = if (this.ub_init == "heuristic") then " (heuristic)" else "";
      writeln("Initial upper bound: ", this.initUB, heuristic);
      writeln("Lower bound function: ", this.lb_name);
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
      if isArray(subNodeExplored) {
        writeln("% of the explored tree per ", par_mode, ": ", 100 * subNodeExplored:real / treeSize:real);
      }
      writeln("Number of optimal solutions: ", nbSol);
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
      return "./chpl_qap.txt";
    }

    override proc help_message(): void
    {
      writeln("\n  Quadratic Assignment Problem Parameters:\n");
      writeln("   --inst    str       file(s) containing the instance data");
      writeln("   --itmax   int       maximum number of bounding iterations");
      writeln("   --lb      str       lower bound function ('glb' or 'hhb')");
      writeln("   --ub      str/int   upper bound initialization ('heuristic' or any integer)\n");
    }

  } // end class
}
