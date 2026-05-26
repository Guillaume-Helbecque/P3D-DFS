module Problem_QAP
{
  use List;
  use CTypes;

  use Problem;
  use Instances;
  use Header_chpl_c_QAP;

  const allowedLowerBounds = ["glb", "iglb", "evb", "rlt1", "rlt2", "qpb"];

  param INF: int = max(int);
  param INF32: int(32) = max(int(32));

  class Problem_QAP : Problem
  {
    var filename: string;
    var benchmark: string;
    var n: int(32);
    var N: int(32);
    var F: c_ptr(c_int);
    var D: c_ptr(c_int);

    var priority_fac: [0..<n] int(32);
    var priority_loc: [0..<N] int(32);

    var it_max: int(32);
    var tol: real;

    var lb_name: string;

    var ub_init: string;
    var initUB: int;

    // QPB-specific integer-symmetry flags for F and D.
    var f_symmetric: c_int;
    var d_symmetric: c_int;

    proc init(filename, itmax, tol, lb, ub): void
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

      this.F = allocate(c_int, N**2);
      this.D = allocate(c_int, N**2);
      inst.get_flow(this.F);
      inst.get_distance(this.D);

      this.f_symmetric = is_symmetric_matrix_c(this.F, this.n, this.N);
      this.d_symmetric = is_symmetric_matrix_c(this.D, this.N, this.N);

      Prioritization(this.priority_fac, this.F, this.n, ascend = false);
      if (this.benchmark == "qubitAlloc") then
        Prioritization_loc_connec(this.D, this.N);
      else
        Prioritization(this.priority_loc, this.D, this.N);

      if (allowedLowerBounds.find(lb) != -1) then this.lb_name = lb;
      else halt("Error - Unsupported lower bound");

      // Apply LB-specific defaults for itmax and tol
      if (itmax > 0) {
        this.it_max = itmax;
      } else if (this.lb_name == "qpb") {
        this.it_max = 15;
      } else {
        this.it_max = 25;
      }

      if (tol > 0.0) {
        this.tol = tol;
      } else if (this.lb_name == "qpb") {
        this.tol = 1e-5;
      } else {
        this.tol = 1e-6;
      }

      this.ub_init = ub;
      if (ub == "heuristic") {
        // The greedy fills `best_mapping` with its best assignment, then 2-opt
        // refines it in place and returns the tightened objective cost.
        var best_mapping: [0..<this.n] int(32);
        this.initUB = GreedyAllocation(this.D, this.F, this.priority_fac, this.n, this.N, best_mapping);
        this.initUB = LocalSearch2Opt(this.D, this.F, this.n, this.N, best_mapping);
      }
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

    proc deinit()
    {
      deallocate(F);
      deallocate(D);
    }

    override proc copy()
    {
      return new Problem_QAP(this.filename, this.it_max, this.tol, this.lb_name, this.ub_init);
    }

    proc RowwiseNumZeros(const ref D, const N)
    {
      var nzD: [0..#N] int(32);

      for i in 0..<N {
        for j in 0..<N {
          if !D[i * N + j] then
            nzD[i] += 1;
        }
      }

      return nzD;
    }

    proc Prioritization(ref priority, const ref F, n: int(32), ascend = true)
    {
      var sF: [0..<n] int(32);

      for i in 0..<n do
        for j in 0..<n do
          sF[i] += F[i * this.N + j] + F[j * this.N + i];

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

        // Remove the contribution of the just-picked index in both directions.
        for j in 0..<n {
          if (sF[j] != INF32) then
            sF[j] -= F[j * this.N + min_inter_index]
                   + F[min_inter_index * this.N + j];
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

    proc GreedyAllocation(const ref D, const ref F, const ref priority, n, N,
      ref best_mapping: [] int(32))
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
                cost_incre += F[i * N + k] * D[alloc_temp[i] * N + l]
                            + F[k * N + i] * D[l * N + alloc_temp[i]];
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

        if (route_cost_temp < route_cost) {
          route_cost = route_cost_temp;
          best_mapping = alloc_temp;
        }
      }

      return route_cost;
    }

    /*
      2-opt local search. Starts from `mapping` and repeatedly swaps pairs of
      location assignments whenever the swap strictly reduces the objective
      cost.
    */
    proc LocalSearch2Opt(const ref D, const ref F, n: int(32), N: int(32),
      ref mapping: [] int(32)): int
    {
      var bestCost: int = ObjectiveFunction(mapping, D, F, n);
      var improved = true;

      while improved {
        improved = false;

        for i in 0..<n {
          for j in (i+1)..<n {
            const a = mapping[i];
            const b = mapping[j];

            // Contributions that don't involve any third index k.
            var delta: int =
                (F[i * N + i]:int - F[j * N + j]:int) * (D[b * N + b]:int - D[a * N + a]:int)
              + (F[i * N + j]:int - F[j * N + i]:int) * (D[b * N + a]:int - D[a * N + b]:int);

            // Contributions from every third facility k (and both directions
            // of the flow/distance product, since QAP is not assumed symmetric).
            for k in 0..<n {
              if (k == i || k == j) then continue;
              delta += (F[i * N + k]:int - F[j * N + k]:int)
                     * (D[b * N + mapping[k]]:int - D[a * N + mapping[k]]:int)
                     + (F[k * N + i]:int - F[k * N + j]:int)
                     * (D[mapping[k] * N + b]:int - D[mapping[k] * N + a]:int);
            }

            if (delta < 0) {
              mapping[i] <=> mapping[j];
              bestCost += delta;
              improved = true;
            }
          }
        }
      }

      return bestCost;
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

          route_cost += F[i * this.N + j] * D[mapping[i] * this.N + mapping[j]];
        }
      }

      return route_cost;
    }

    /*******************************************************
                       RLT1-BASED BOUND
    *******************************************************/

    proc decompose_RLT1(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, ref best: int, lock: sync bool, ref best_task: int): list(?)
    {
      var children: list(Node);

      var depth = parent.depth;

      if (parent.depth == this.n) {
        const eval = ObjectiveFunction(parent.mapping, this.D, this.F, this.n);

        if (eval < best_task) {
          best_task = eval;
          lock.readFE();
          if (eval <= best) {
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
        if (parent.lower_bound >= best_task) {
          return children;
        }
        /* local { */
          var i = this.priority_fac[depth];

          // Pull any cross-task improvement into the task-local UB before
          // bounding. bound_RLT1 uses *best as its UB for loop termination
          // (`lb < 2*UB`), so the tighter this is, the fewer iterations it runs
          // and the tighter its returned bound. Without this, a task that
          // started with the initial UB would keep using it even after another
          // task has already improved `best` via a leaf.
          if (best < best_task) then best_task = best;

          var parentWarm: c_ptr(RLT_WarmData_wrapper) = nil;

          // Step 1: Recompute the parent's bound on the reduced subproblem.
          if (depth + 1 < this.n) {
            parentWarm = RLT_WarmData_wrapper_new();

            const lb_parent = bound_RLT1(parent.mapping, parent.available, depth:c_int,
              this.F, this.D, this.n:c_int, this.N:c_int, this.it_max, this.tol, best_task,
              nil, nil, -1:c_int, -1:c_int, parentWarm);

            // bound_RLT1 may have tightened best_task via its internal
            // Hungarian candidate.
            if (best_task < best) {
              lock.readFE();
              if (best_task < best) {
                best = best_task;
                num_sol = 0;
              }
              else {
                best_task = best;
              }
              lock.writeEF(true);
            }

            // early-prune signal if the parent lb already exceeds best_task
            if (lb_parent >= best_task) {
              RLT_WarmData_wrapper_free(parentWarm);
              return children;
            }
          }

          // Step 2: Enumerate children, reusing the parent's warm data.
          for j0 in 0..<this.N by -1 {
            const j = this.priority_loc[j0];

            if !parent.available[j] then continue; // skip if not available

            var child = new Node(parent);
            child.depth += 1;
            child.mapping[i] = j;
            child.available[j] = 0;

            if (child.depth < this.n) {
              const lb = bound_RLT1(child.mapping, child.available, child.depth:c_int,
                this.F, this.D, this.n:c_int, this.N:c_int, this.it_max, this.tol, best_task,
                nil, parentWarm, i:c_int, j:c_int, nil);

              // Same UB propagation as after the parent bound.
              if (best_task < best) {
                lock.readFE();
                if (best_task < best) {
                  best = best_task;
                  num_sol = 0;
                }
                else {
                  best_task = best;
                }
                lock.writeEF(true);
              }

              if (lb < best_task) {
                child.lower_bound = lb;
                children.pushBack(child);
                tree_loc += 1;
              }
            }
            else {
              children.pushBack(child);
              tree_loc += 1;
            }
          }

          if (parentWarm != nil) {
            RLT_WarmData_wrapper_free(parentWarm);
          }
        /* } */
      }

      return children;
    }

    /*******************************************************
                       RLT2-BASED BOUND
    *******************************************************/

    proc decompose_RLT2(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, ref best: int, lock: sync bool, ref best_task: int): list(?)
    {
      var children: list(Node);

      var depth = parent.depth;

      if (parent.depth == this.n) {
        const eval = ObjectiveFunction(parent.mapping, this.D, this.F, this.n);

        if (eval < best_task) {
          best_task = eval;
          lock.readFE();
          if (eval <= best) {
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
        if (parent.lower_bound >= best_task) {
          return children;
        }
        /* local { */
          var i = this.priority_fac[depth];

          // Pull any cross-task improvement into the task-local UB before
          // bounding. bound_RLT2 uses *best as its UB for loop termination
          // (`lb < 2*UB`), so the tighter this is, the fewer iterations it runs
          // and the tighter its returned bound. Without this, a task that
          // started with the initial UB would keep using it even after another
          // task has already improved `best` via a leaf.
          if (best < best_task) then best_task = best;

          var parentWarm: c_ptr(RLT_WarmData_wrapper) = nil;

          // Step 1: Recompute the parent's bound on the reduced subproblem.
          if (depth + 1 < this.n) {
            parentWarm = RLT_WarmData_wrapper_new();

            const lb_parent = bound_RLT2(parent.mapping, parent.available, depth:c_int,
              this.F, this.D, this.n:c_int, this.N:c_int, this.it_max, this.tol, best_task,
              nil, nil, -1:c_int, -1:c_int, parentWarm);

            // bound_RLT2 may have tightened best_task via its internal
            // Hungarian candidate.
            if (best_task < best) {
              lock.readFE();
              if (best_task < best) {
                best = best_task;
                num_sol = 0;
              }
              else {
                best_task = best;
              }
              lock.writeEF(true);
            }

            // early-prune signal if the parent lb already exceeds best_task
            if (lb_parent >= best_task) {
              RLT_WarmData_wrapper_free(parentWarm);
              return children;
            }
          }

          // Step 2: Enumerate children, reusing the parent's warm data.
          for j0 in 0..<this.N by -1 {
            const j = this.priority_loc[j0];

            if !parent.available[j] then continue; // skip if not available

            var child = new Node(parent);
            child.depth += 1;
            child.mapping[i] = j;
            child.available[j] = 0;

            if (child.depth < this.n) {
              const lb = bound_RLT2(child.mapping, child.available, child.depth:c_int,
                this.F, this.D, this.n:c_int, this.N:c_int, this.it_max, this.tol, best_task,
                nil, parentWarm, i:c_int, j:c_int, nil);

              // Same UB propagation as after the parent bound.
              if (best_task < best) {
                lock.readFE();
                if (best_task < best) {
                  best = best_task;
                  num_sol = 0;
                }
                else {
                  best_task = best;
                }
                lock.writeEF(true);
              }

              if (lb < best_task) {
                child.lower_bound = lb;
                children.pushBack(child);
                tree_loc += 1;
              }
            }
            else {
              children.pushBack(child);
              tree_loc += 1;
            }
          }

          if (parentWarm != nil) {
            RLT_WarmData_wrapper_free(parentWarm);
          }
        /* } */
      }

      return children;
    }

    /*******************************************************
                      GILMORE-LAWLER BOUND
    *******************************************************/

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
          if (eval <= best) {
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

          for j0 in 0..<this.N by -1 {
            const j = this.priority_loc[j0];

            if !parent.available[j] then continue; // skip if not available

            var child = new Node(parent);
            child.depth += 1;
            child.mapping[i] = j;
            child.available[j] = 0;

            if (child.depth < this.n) {
              var lb = bound_GLB(child.mapping, child.available, depth:c_int,
                this.F, this.D, this.n:c_int, this.N:c_int);

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
                  IMPROVED GILMORE-LAWLER BOUND
    *******************************************************/

    proc decompose_IGLB(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, ref best: int, lock: sync bool, ref best_task: int): list(?)
    {
      var children: list(Node);

      var depth = parent.depth;

      if (parent.depth == this.n) {
        const eval = ObjectiveFunction(parent.mapping, this.D, this.F, this.n);

        if (eval < best_task) {
          best_task = eval;
          lock.readFE();
          if (eval <= best) {
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

          for j0 in 0..<this.N by -1 {
            const j = this.priority_loc[j0];

            if !parent.available[j] then continue; // skip if not available

            var child = new Node(parent);
            child.depth += 1;
            child.mapping[i] = j;
            child.available[j] = 0;

            if (child.depth < this.n) {
              var lb = bound_IGLB(child.mapping, child.available, child.depth:c_int,
                this.F, this.D, this.n:c_int, this.N:c_int);

              if (lb < best_task) {
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
                      EIGENVALUE-BASED BOUND
    *******************************************************/

    proc decompose_EVB(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, ref best: int, lock: sync bool, ref best_task: int): list(?)
    {
      var children: list(Node);

      var depth = parent.depth;

      if (parent.depth == this.n) {
        const eval = ObjectiveFunction(parent.mapping, this.D, this.F, this.n);

        if (eval < best_task) {
          best_task = eval;
          lock.readFE();
          if (eval <= best) {
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
        if (best < best_task) then best_task = best;

        local {
          var i = this.priority_fac[depth];

          for j0 in 0..<this.N by -1 {
            const j = this.priority_loc[j0];

            if !parent.available[j] then continue; // skip if not available

            var child = new Node(parent);
            child.depth += 1;
            child.mapping[i] = j;
            child.available[j] = 0;

            if (child.depth < this.n) {
              var lb = bound_EVB(child.mapping, child.available, child.depth:c_int,
                this.F, this.D, this.n:c_int, this.N:c_int, best_task);

              if (lb < best_task) {
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
                QUADRATIC-PROGRAMMING-BASED BOUND
    *******************************************************/

    proc decompose_QPB(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, ref best: int, lock: sync bool, ref best_task: int): list(?)
    {
      var children: list(Node);

      var depth = parent.depth;

      if (parent.depth == this.n) {
        const eval = ObjectiveFunction(parent.mapping, this.D, this.F, this.n);

        if (eval < best_task) {
          best_task = eval;
          lock.readFE();
          if (eval <= best) {
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
        if (parent.lower_bound >= best_task) {
          return children;
        }

        const i = this.priority_fac[depth];

        // Pull any cross-task improvement into the task-local UB before
        // bounding. bound_QPB_child uses UB as the FW early-termination
        // target, so the tighter this is, the fewer FW iterations the solver
        // runs.
        if (best < best_task) then best_task = best;

        if (depth + 1 == this.n) {
          // All children are leaves -- no QPB context, no bounding. Just
          // enumerate the remaining available locations and push each child
          // for the leaf-evaluation branch (`parent.depth == this.n`) to
          // pick up on the next decompose.
          local {
            for j0 in 0..<this.N by -1 {
              const j = this.priority_loc[j0];

              if !parent.available[j] then continue; // skip if not available

              var child = new Node(parent);
              child.depth += 1;
              child.mapping[i] = j;
              child.available[j] = 0;
              children.pushBack(child);
              tree_loc += 1;
            }
          }
        }
        else {
          // Build QPB parent context once. The context owns the precomputed
          // parent_C, the A-side eigen cache, child_uf, A_sub, and the FW
          // solver scratch. The parent's QPB buffers are always passed (the
          // c_arrays are inline storage, never nil); the wrapper ignores them
          // when parent_qpb_has_data == 0.
          var qpb_ctx = QPB_ParentContext_new(
            parent.mapping, parent.available,
            depth:c_int, i:c_int,
            this.F, this.D, this.n:c_int, this.N:c_int,
            this.it_max, this.tol,
            parent.qpb_has_data, parent.qpb_m,
            parent.qpb_X, parent.qpb_reduced_costs,
            parent.qpb_unassigned_fac, parent.qpb_unassigned_loc,
            parent.qpb_fixed_cost, parent.qpb_bound_cont_last,
            this.f_symmetric, this.d_symmetric);

          // Enumerate children in reverse priority order (DFS). Inside the
          // local block: the wrapper is extern C / purely computational,
          // parent / this fields are accessed via already-resolved pointers,
          // and we never touch the cross-task `lock` / `best` here (only
          // `best_task` and the task-local `children` / `tree_loc`). Matches
          // the local-block usage in decompose_GLB.
          local {
            for j0 in 0..<this.N by -1 {
              const j = this.priority_loc[j0];

              if !parent.available[j] then continue; // skip if not available

              var child = new Node(parent);
              child.depth += 1;
              child.mapping[i] = j;
              child.available[j] = 0;

              const lb = bound_QPB_child(
                qpb_ctx, j:c_int, best_task,
                child.qpb_X, child.qpb_reduced_costs,
                child.qpb_unassigned_fac, child.qpb_unassigned_loc,
                child.qpb_m, child.qpb_has_data,
                child.qpb_bound_cont, child.qpb_bound_cont_last,
                child.qpb_fixed_cost);

              // bound_QPB_child returns INT64_MAX (LLONG_MAX) when the
              // cheap variable-fixing prune fires; skip the child entirely.
              if (lb == max(int(64))) then continue;

              if (lb < best_task) {
                child.lower_bound = lb;
                children.pushBack(child);
                tree_loc += 1;
              }
            }
          }

          QPB_ParentContext_free(qpb_ctx);
        }
      }

      return children;
    }

    override proc decompose(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, ref best: int, lock: sync bool, ref best_task: int): list(?)
    {
      select this.lb_name {
        when "rlt1" {
          return decompose_RLT1(Node, parent, tree_loc, num_sol, max_depth, best, lock, best_task);
        }
        when "rlt2" {
          return decompose_RLT2(Node, parent, tree_loc, num_sol, max_depth, best, lock, best_task);
        }
        when "glb" {
          return decompose_GLB(Node, parent, tree_loc, num_sol, max_depth, best, lock, best_task);
        }
        when "iglb" {
          return decompose_IGLB(Node, parent, tree_loc, num_sol, max_depth, best, lock, best_task);
        }
        when "evb" {
          return decompose_EVB(Node, parent, tree_loc, num_sol, max_depth, best, lock, best_task);
        }
        when "qpb" {
          return decompose_QPB(Node, parent, tree_loc, num_sol, max_depth, best, lock, best_task);
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
      if (this.lb_name == "rlt1" || this.lb_name == "rlt2") {
        writeln("Max bounding iterations: ", this.it_max);
        writeln("Convergence relative tolerance: ", this.tol);
      }
      else if (this.lb_name == "qpb") {
        writeln("Max Frank-Wolfe iterations: ", this.it_max);
        writeln("Relative FW duality gap tolerance: ", this.tol);
      }
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
      writeln("                       (default: 25 for 'rlt1'/'rlt2', 15 for 'qpb')");
      writeln("   --tol     real      relative tolerance for the stopping criterion");
      writeln("                       (default: 1e-6 for 'rlt1'/'rlt2', 1e-5 for 'qpb')");
      writeln("   --lb      str       lower bound function ('glb', 'iglb', 'evb', 'rlt1', 'rlt2', or 'qpb')");
      writeln("   --ub      str/int   upper bound initialization ('heuristic' or any integer)\n");
    }

  } // end class
}
