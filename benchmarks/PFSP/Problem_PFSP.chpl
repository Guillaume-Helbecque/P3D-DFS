module Problem_PFSP
{
  use aux;
  use List;
  use Time;
  use CTypes;

  use Problem;
  use Instances;
  use Header_chpl_c_PFSP;

  const allowedLowerBounds = ["lb1", "lb1_d", "lb2"];
  const allowedBranchingRules = ["fwd", "bwd", "alt", "maxSum", "minMin", "minBranch"];

  class Problem_PFSP : Problem
  {
    var name: string;
    var jobs: c_int;
    var machines: c_int;

    var lb_name: string;
    var lbound1: c_ptr(bound_data);
    var lbound2: c_ptr(johnson_bd_data);

    var branching: string;
    var ub_init: string;

    proc init(const fileName: string, const lb: string, const rules: string, const ub: string): void
    {
      this.name = fileName;

      var inst = new Instance();
      if (fileName[0..1] == "ta") then inst = new Instance_Taillard(fileName);
      else if (fileName[0..2] == "VFR") then inst = new Instance_VRF(fileName);
      else halt("Error - Unknown PFSP instance class");

      this.jobs     = inst.get_nb_jobs();
      this.machines = inst.get_nb_machines();

      if (allowedLowerBounds.find(lb) != -1) then this.lb_name = lb;
      else halt("Error - Unsupported lower bound");

      this.lbound1 = new_bound_data(jobs, machines);
      inst.get_data(lbound1.deref().p_times);
      fill_min_heads_tails(lbound1);

      if (lb == "lb2") {
        this.lbound2 = new_johnson_bd_data(lbound1/*, LB2_FULL*/);
        fill_machine_pairs(lbound2/*, LB2_FULL*/);
        fill_lags(lbound1, lbound2);
        fill_johnson_schedules(lbound1, lbound2);
      }

      if (allowedBranchingRules.find(rules) != -1) then this.branching = rules;
      else halt("Error - Unsupported branching rule");

      if (ub == "opt" || ub == "inf") then this.ub_init = ub;
      else halt("Error - Unsupported upper bound");
    }

    // TODO: Implement a copy initializer, to avoid re-computing all the data
    override proc copy()
    {
      return new Problem_PFSP(this.name, this.lb_name, this.branching, this.ub_init);
    }

    proc branchingRule(const lb_begin: [], const lb_end: [], const depth, const best)
    {
      var branch = this.branching;

      while true {
        select branch {
          when "fwd" {
            return (0, lb_begin); // begin
          }
          when "bwd" {
            return (1, lb_end); // end
          }
          when "alt" {
            if (depth % 2 == 0) then branch = "fwd";
            else branch = "bwd";
          }
          when "maxSum" {
            var sum1 = (+ reduce lb_begin);
            var sum2 = (+ reduce lb_end);
            if (sum1 >= sum2) then branch = "fwd";
            else branch = "bwd";
          }
          when "minMin" {
            var min1, min2: c_int = 99999;
            for k in 0..#this.jobs {
              if (lb_begin[k] != 0) then min1 = min(lb_begin[k], min1);
              if (lb_end[k] != 0) then min2 = min(lb_end[k], min2);
            }
            var min3 = min(min1, min2);
            var c1 = lb_begin.count(min3);
            var c2 = lb_end.count(min3);
            if (c1 < c2) then branch = "fwd";
            else if (c1 == c2) then branch = "minBranch";
            else branch = "bwd";
          }
          when "minBranch" {
            var c1, c2, s1, s2: int;
            for k in 0..#this.jobs {
              if (lb_begin[k] > best) then c1 += 1;
              else s1 += lb_begin[k];

              if (lb_end[k] > best) then c2 += 1;
              else s2 += lb_end[k];
            }
            if (c1 < c2) then branch = "bwd";
            else if (c1 > c2) then branch = "fwd";
            else {
              if (s1 >= s2) then branch = "fwd";
              else branch = "bwd";
            }
          }
        }
      }
      return (0, lb_begin);
    }

    proc decompose_lb1(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, best: atomic int, ref best_task: int): list
    {
      var children: list(Node);

      for i in parent.limit1+1..parent.limit2-1 {
        var child = new Node(parent);
        swap(child.prmu[child.depth], child.prmu[i]);
        child.depth  += 1;
        child.limit1 += 1;

        var lowerbound = lb1_bound(lbound1, child.prmu, child.limit1:c_int, jobs);

        if (child.depth == jobs) { // if child leaf
          num_sol += 1;

          if (lowerbound < best_task) { // if child feasible
            best_task = lowerbound;
            best.write(lowerbound);
          }
        } else { // if not leaf
          if (lowerbound < best_task) { // if child feasible
            children.append(child);
            tree_loc += 1;
          }
        }
      }

      return children;
    }

    proc decompose_lb1_d(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, best: atomic int, ref best_task: int): list
    {
      var children: list(Node);

      var lb_begin: [0..#this.jobs] c_int;
      var lb_end: [0..#this.jobs] c_int;
      var prio_begin: [0..#this.jobs] c_int;
      var prio_end: [0..#this.jobs] c_int;

      /* TODO: optimize BEGINEND */
      /* What is the meaning of prio_begin/end ? */
      var BEGINEND: c_int = 0;

      lb1_children_bounds(this.lbound1, parent.prmu, parent.limit1:c_int, parent.limit2:c_int,
        c_ptrTo(lb_begin), c_ptrTo(lb_end), c_ptrTo(prio_begin), c_ptrTo(prio_end), BEGINEND);

      var (beginEnd, lbs) = branchingRule(lb_begin, lb_end, parent.depth, best_task);

      for i in parent.limit1+1..parent.limit2-1 {
        const job = parent.prmu[i];
        const lb = lbs[job];

        if (parent.depth + 1 == jobs) { // if child leaf
          num_sol += 1;

          if (lb < best_task) { // if child feasible
            best_task = lb;
            best.write(lb);
          }
        } else { // if not leaf
          if (lb < best_task) { // if child feasible
            var child = new Node(parent);
            child.depth += 1;

            if (beginEnd == 0) { // begin
              child.limit1 += 1;
              swap(child.prmu[child.limit1], child.prmu[i]);
            } else if (beginEnd == 1) { // end
              child.limit2 -= 1;
              swap(child.prmu[child.limit2], child.prmu[i]);
            }

            children.append(child);
            tree_loc += 1;
          }
        }

      }

      return children;
    }

    proc decompose_lb2(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, best: atomic int, ref best_task: int): list
    {
      var children: list(Node);

      for i in parent.limit1+1..parent.limit2-1 {
        var child = new Node(parent);
        swap(child.prmu[child.depth], child.prmu[i]);
        child.depth  += 1;
        child.limit1 += 1;

        var lowerbound = lb2_bound(lbound1, lbound2, child.prmu, child.limit1:c_int, jobs, best_task:c_int);

        if (child.depth == jobs) { // if child leaf
          num_sol += 1;

          if (lowerbound < best_task) { // if child feasible
            best_task = lowerbound;
            best.write(lowerbound);
          }
        } else { // if not leaf
          if (lowerbound < best_task) { // if child feasible
            children.append(child);
            tree_loc += 1;
          }
        }

      }

      return children;
    }

    override proc decompose(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, best: atomic int, ref best_task: int): list
    {
      select this.lb_name {
        when "lb1" {
          return decompose_lb1(Node, parent, tree_loc, num_sol, max_depth, best, best_task);
        }
        when "lb1_d" {
          return decompose_lb1_d(Node, parent, tree_loc, num_sol, max_depth, best, best_task);
        }
        when "lb2" {
          return decompose_lb2(Node, parent, tree_loc, num_sol, max_depth, best, best_task);
        }
        otherwise {
          halt("DEADCODE");
        }
      }
    }

    override proc setInitUB(): int
    {
      var inst = new Instance();
      if (this.name[0..1] == "ta") then inst = new Instance_Taillard(this.name);
      else inst = new Instance_VRF(this.name);

      if (this.ub_init == "inf") {
        return 999999;
      }
      else {
        return inst.get_ub();
      }
    }

    proc free(): void
    {
      free_bound_data(this.lbound1);
      if (this.lb_name == "lb2") then free_johnson_bd_data(this.lbound2);
    }

    // =======================
    // Utility functions
    // =======================

    override proc print_settings(): void
    {
      writeln("\n=================================================");
      writeln("PFSP instance: ", this.name, " (m = ", this.machines, ", n = ", this.jobs, ")");
      writeln("Initial upper bound: ", setInitUB());
      writeln("Lower bound function: ", this.lb_name);
      writeln("Branching rules: ", this.branching);
      writeln("=================================================");
    }

    override proc print_results(const subNodeExplored: [] int, const subSolExplored: [] int,
      const subDepthReached: [] int, const best: int, const timer: stopwatch): void
    {
      var treeSize: int = (+ reduce subNodeExplored);
      var nbSol: int = (+ reduce subSolExplored);
      var par_mode: string = if (numLocales == 1) then "tasks" else "locales";

      writeln("\n=================================================");
      writeln("Size of the explored tree: ", treeSize);
      /* writeln("Size of the explored tree per locale: ", sizePerLocale); */
      writeln("% of the explored tree per ", par_mode, ": ", 100 * subNodeExplored:real / treeSize:real);
      writeln("Number of explored solutions: ", nbSol);
      /* writeln("Number of explored solutions per locale: ", numSolPerLocale); */
      writeln("Optimal makespan: ", best);
      writeln("Elapsed time: ", timer.elapsed(), " [s]");
      writeln("=================================================\n");
    }

    override proc output_filepath(): string
    {
      var tup = ("./chpl_pfsp_", this.name, "_", this.lb_name, "_", this.branching, ".txt");
      return "".join(tup);
    }

    override proc help_message(): void
    {
      writeln("\n  PFSP Benchmark Parameters:\n");
      writeln("   --inst  str   instance's name");
      writeln("   --lb    str   lower bound function (lb1, lb1_d, lb2)");
      writeln("   --br    str   branching rule (fwd, bwd, alt, maxSum, minMin, minBranch)");
      writeln("   --ub    str   upper bound initialization (opt, inf)\n");
    }

  } // end class

} // end module
