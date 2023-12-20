module Problem_PFSP
{
  use List;
  use Path;
  use CTypes;

  use Problem;
  use Instances;
  use Header_chpl_c_PFSP;

  require "../../commons/c_sources/aux.c", "../../commons/c_headers/aux.h";
  extern proc swap(ref a: c_int, ref b: c_int): void;

  const allowedLowerBounds = ["lb1", "lb1_d", "lb2"];
  const allowedBranchingRules = ["fwd", "bwd", "alt", "maxSum", "minMin", "minBranch"];

  const BEGIN: c_int = -1;
  const BEGINEND: c_int = 0;
  const END: c_int = 1;

  class Problem_PFSP : Problem
  {
    var name: string;
    var jobs: c_int;
    var machines: c_int;

    var lb_name: string;
    var lbound1: c_ptr(bound_data);
    var lbound2: c_ptr(johnson_bd_data);

    var branching: string;
    var branchingSide: c_int;

    var ub_init: string;
    var initUB: int;

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

      if (rules == "fwd") then this.branchingSide = BEGIN;
      else if (rules == "bwd") then this.branchingSide = END;
      else this.branchingSide = BEGINEND;

      this.ub_init = ub;
      if (ub == "opt") then this.initUB = inst.get_best_ub();
      else if (ub == "inf") then this.initUB = max(int);
      else halt("Error - Unsupported initial upper bound");
    }

    proc deinit()
    {
      free_bound_data(this.lbound1);
      if (this.lb_name == "lb2") then free_johnson_bd_data(this.lbound2);
    }

    // TODO: Implement a copy initializer, to avoid re-computing all the data
    override proc copy()
    {
      return new Problem_PFSP(this.name, this.lb_name, this.branching, this.ub_init);
    }

    inline proc branchingRule(const lb_begin, const lb_end, const depth, const best)
    {
      var branch = this.branching;

      while true {
        select branch {
          when "alt" {
            if (depth % 2 == 0) then return BEGIN;
            else return END;
          }
          when "maxSum" {
            var sum1, sum2 = 0;
            for i in 0..#this.jobs {
              sum1 += lb_begin[i];
              sum2 += lb_end[i];
            }
            if (sum1 >= sum2) then return BEGIN;
            else return END;
          }
          when "minMin" {
            var min0 = 99999;
            for k in 0..#this.jobs {
              if lb_begin[k] then min0 = min(lb_begin[k], min0);
              if lb_end[k] then min0 = min(lb_end[k], min0);
            }
            var c1, c2 = 0;
            for k in 0..#this.jobs {
              if (lb_begin[k] == min0) then c1 += 1;
              if (lb_end[k] == min0) then c2 += 1;
            }
            if (c1 < c2) then return BEGIN;
            else if (c1 == c2) then branch = "minBranch";
            else return END;
          }
          when "minBranch" {
            var c, s: int;
            for i in 0..#this.jobs {
              if (lb_begin[i] >= best) then c += 1;
              if (lb_end[i] >= best) then c -= 1;
              s += (lb_begin[i] - lb_end[i]);
            }
            if (c > 0) then return BEGIN;
            else if (c < 0) then return END;
            else {
              if (s < 0) then return END;
              else return BEGIN;
            }
          }
          otherwise halt("Error - Unsupported branching rule");
        }
      }
      halt("DEADCODE");
    }

    proc decompose_lb1(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, best: atomic int, ref best_task: int): list(?)
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
            children.pushBack(child);
            tree_loc += 1;
          }
        }
      }

      return children;
    }

    proc decompose_lb1_d(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, best: atomic int, ref best_task: int): list(?)
    {
      var children: list(Node);

      var lb_begin = allocate(c_int, this.jobs);
      var lb_end = allocate(c_int, this.jobs);
      /* var prio_begin = allocate(c_int, this.jobs);
      var prio_end = allocate(c_int, this.jobs); */
      var beginEnd = this.branchingSide;

      lb1_children_bounds(this.lbound1, parent.prmu, parent.limit1:c_int, parent.limit2:c_int,
        lb_begin, lb_end, nil, nil, beginEnd);

      if (this.branchingSide == BEGINEND) {
        beginEnd = branchingRule(lb_begin, lb_end, parent.depth, best_task);
      }

      for i in parent.limit1+1..parent.limit2-1 {
        const job = parent.prmu[i];
        const lb = (beginEnd == BEGIN) * lb_begin[job] + (beginEnd == END) * lb_end[job];

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

            if (beginEnd == BEGIN) {
              child.limit1 += 1;
              swap(child.prmu[child.limit1], child.prmu[i]);
            } else if (beginEnd == END) {
              child.limit2 -= 1;
              swap(child.prmu[child.limit2], child.prmu[i]);
            }

            children.pushBack(child);
            tree_loc += 1;
          }
        }

      }

      deallocate(lb_begin); deallocate(lb_end);
      /* deallocate(prio_begin); deallocate(prio_end); */

      return children;
    }

    proc decompose_lb2(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, best: atomic int, ref best_task: int): list(?)
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
            children.pushBack(child);
            tree_loc += 1;
          }
        }

      }

      return children;
    }

    override proc decompose(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, best: atomic int, ref best_task: int): list(?)
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

    override proc getInitBound(): int
    {
      return this.initUB;
    }

    // =======================
    // Utility functions
    // =======================

    override proc print_settings(): void
    {
      writeln("\n=================================================");
      writeln("PFSP instance: ", this.name, " (m = ", this.machines, ", n = ", this.jobs, ")");
      writeln("Initial upper bound: ", this.initUB);
      writeln("Lower bound function: ", this.lb_name);
      writeln("Branching rule: ", this.branching);
      writeln("=================================================");
    }

    override proc print_results(const subNodeExplored: [] int, const subSolExplored: [] int,
      const subDepthReached: [] int, const best: int, const elapsedTime: real): void
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
      const is_better = if (best < this.initUB) then " (improved)"
                                                else " (not improved)";
      writeln("Optimal makespan: ", best, is_better);
      writeln("Elapsed time: ", elapsedTime, " [s]");
      writeln("=================================================\n");
    }

    override proc output_filepath(): string
    {
      return "./chpl_pfsp_" + splitExt(this.name)[0] + "_" + this.lb_name +
              "_" + this.branching + ".txt";
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
