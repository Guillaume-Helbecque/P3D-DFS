module Problem_PFSP
{
  use aux;
  use List;
  use Time;
  use CTypes;

  use Problem;
  use Header_chpl_c_PFSP;

  class Problem_PFSP : Problem
  {
    var Ta_inst: c_int;
    var machines: c_int;
    var jobs: c_int;

    var lb_name: string;
    var lbound1: c_ptr(bound_data);
    var lbound2: c_ptr(johnson_bd_data);

    var branching: int;
    var ub_init: string;

    proc init(const inst: c_int, const lb: string, const rules: int, const ub: string): void
    {
      if (0 < inst && inst < 121) then this.Ta_inst = inst;
      else halt("Error - Unknown Taillard instance");

      this.machines = taillard_get_nb_machines(inst);
      this.jobs = taillard_get_nb_jobs(inst);

      if (lb == "lb1" || lb == "lb1_d" || lb == "lb2") then this.lb_name = lb;
      else halt("Error - Unsupported lower bound");

      select lb_name {
        when "lb1" {
          this.lbound1 = new_bound_data(jobs, machines);
          taillard_get_processing_times_d(lbound1, inst);
          fill_min_heads_tails(lbound1);
          /* lbound2 = c_void_ptr; */
        }
        when "lb1_d" {
          this.lbound1 = new_bound_data(jobs, machines);
          taillard_get_processing_times_d(lbound1, inst);
          fill_min_heads_tails(lbound1);
          /* lbound2 = c_void_ptr; */
        }
        when "lb2" {
          this.lbound1 = new_bound_data(jobs, machines);
          taillard_get_processing_times_d(lbound1, inst);
          fill_min_heads_tails(lbound1);

          this.lbound2 = new_johnson_bd_data(lbound1/*, LB2_FULL*/);
          fill_machine_pairs(lbound2/*, LB2_FULL*/);
          fill_lags(lbound1, lbound2);
          fill_johnson_schedules(lbound1, lbound2);
        }
      }

      this.branching = rules;

      if (ub == "opt" || ub == "inf") then this.ub_init = ub;
      else halt("Error - Unsupported upper bound");
    }

    override proc copy()
    {
      return new Problem_PFSP(Ta_inst, lb_name, branching, ub_init);
    }

    proc decompose_lb1(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      best: atomic int, ref best_task: int): list
    {
      var childList: list(Node); // list containing the child nodes

      // Treatment of childs
      for i in parent.limit1+1..parent.limit2-1 {
        var child = new Node(parent);
        swap(child.prmu[child.depth], child.prmu[i]);
        child.depth  += 1;
        child.limit1 += 1;

        var lowerbound: c_int = lb1_bound(lbound1, child.prmu, child.limit1:c_int, jobs);

        if (child.depth == jobs) { // if child leaf
          num_sol += 1;

          if (lowerbound < best_task) { // if child feasible
            best_task = lowerbound;
            best.write(lowerbound);
          }
        } else { // if not leaf
          if (lowerbound < best_task) { // if child feasible
            tree_loc += 1;
            childList.append(child);
          }
        }
      }

      return childList;
    }

    proc decompose_lb1_d(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      best: atomic int, ref best_task: int): list
    {
      var childList: list(Node); // list containing the child nodes

      var lb_begin = c_malloc(c_int, jobs);
      var BEGINEND: c_int = -1;

      lb1_children_bounds(this.lbound1, parent.prmu, parent.limit1:c_int, parent.limit2:c_int,
        lb_begin, c_nil, c_nil, c_nil, BEGINEND);

      // Treatment of childs
      for i in parent.limit1+1..parent.limit2-1 {

        if (parent.depth + 1 == jobs){ // if child leaf
          num_sol += 1;

          if (lb_begin[parent.prmu[i]] < best_task){ // if child feasible
            best_task = lb_begin[parent.prmu[i]];
            best.write(lb_begin[parent.prmu[i]]);
          }
        } else { // if not leaf
          if (lb_begin[parent.prmu[i]] < best_task){ // if child feasible
            var child = new Node(parent);
            child.depth += 1;

            if (branching == 0){ // if forward
              child.limit1 += 1;
              swap(child.prmu[child.limit1], child.prmu[i]);
            } else if (branching == 1){ // if backward
              child.limit2 -= 1;
              swap(child.prmu[child.limit2], child.prmu[i]);
            }

            childList.append(child);
            tree_loc += 1;
          }
        }

      }

      c_free(lb_begin);

      return childList;
    }

    proc decompose_lb2(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      best: atomic int, ref best_task: int): list
    {
      var childList: list(Node); // list containing the child nodes

      for i in parent.limit1+1..parent.limit2-1 {
        var child = new Node(parent);
        swap(child.prmu[child.depth], child.prmu[i]);
        child.depth  += 1;
        child.limit1 += 1;

        var lowerbound: c_int = lb2_bound(lbound1, lbound2, child.prmu, child.limit1:c_int, jobs, best_task:c_int);

        if (child.depth == jobs) { // if child leaf
          num_sol += 1;

          if (lowerbound < best_task) { // if child feasible
            best_task = lowerbound;
            best.write(lowerbound);
          }
        } else { // if not leaf
          if (lowerbound < best_task) { // if child feasible
            tree_loc += 1;
            childList.append(child);
          }
        }

      }

      return childList;
    }

    override proc decompose(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int, best: atomic int,
      ref best_task: int): list
    {
      select lb_name {
        when "lb1" {
          return decompose_lb1(Node, parent, tree_loc, num_sol, best, best_task);
        }
        when "lb1_d" {
          return decompose_lb1_d(Node, parent, tree_loc, num_sol, best, best_task);
        }
        when "lb2" {
          return decompose_lb2(Node, parent, tree_loc, num_sol, best, best_task);
        }
        otherwise {
          halt("Error - Unknown lower bound");
        }
      }
    }

    override proc setInitUB(): int
    {
      var optimal: [1..120] int =  [1278, 1359, 1081, 1293, 1235, 1195, 1234, 1206, 1230, 1108,            // 20x5
                                    1582, 1659, 1496, 1377, 1419, 1397, 1484, 1538, 1593, 1591,            // 20x10
                                    2297, 2099, 2326, 2223, 2291, 2226, 2273, 2200, 2237, 2178,            // 20x20

                                    2724, 2834, 2621, 2751, 2863, 2829, 2725, 2683, 2552, 2782,            // 50x5
                                    2991, 2867, 2839, 3063, 2976, 3006, 3093, 3037, 2897, 3065,            // 50x10
                                    3850, 3704, 3640, 3723, 3611, 3681, 3704, 3691, 3743, 3756,            // 50x20

                                    5493, 5268, 5175, 5014, 5250, 5135, 5246, 5094, 5448, 5322,            // 100x5
                                    5770, 5349, 5676, 5781, 5467, 5303, 5595, 5617, 5871, 5845,            // 100x10
                                    6202, 6183, 6271, 6269, 6314, 6364, 6268, 6401, 6275, 6434,            // 100x20

                                    10862, 10480, 10922, 10889, 10524, 10329, 10854, 10730, 10438, 10675,  // 200x10
                                    11195, 11203, 11281, 11275, 11259, 11176, 11360, 11334, 11192, 11284,  // 200x20

                                    26040, 26520, 26371, 26456, 26334, 26477, 26389, 26560, 26005, 26457]; // 500x20

      if (ub_init == "inf") {
        return 999999;
      }
      else {
        return optimal[Ta_inst];
      }
    }

    proc free(): void
    {
      select lb_name {
        when "lb1" {
          free_bound_data(lbound1);
        }
        when "lb1_d" {
          free_bound_data(lbound1);
        }
        when "lb2" {
          free_bound_data(lbound1);
          free_johnson_bd_data(lbound2);
        }
      }
    }

    // =======================
    // Utility functions
    // =======================

    override proc print_settings(): void
    {
      writeln("\n=================================================");
      writeln("PFSP Taillard's instance: Ta", Ta_inst, " (m = ", machines, ", n = ", jobs, ")");
      writeln("Initial upper bound: ", setInitUB());
      writeln("Lower bound function: ", lb_name);
      writeln("Branching rules: ", (1-branching)*"forward" + branching*"backward");
      writeln("=================================================");
    }

    override proc print_results(const subNodeExplored: [] int, const subSolExplored: [] int,
      const subDepthReached: [] int, const best: int, const timer: Timer): void
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
      writeln("Elapsed time: ", timer.elapsed(TimeUnits.seconds), " [s]");
      writeln("=================================================\n");
    }

    override proc output_filepath(): string
    {
      var tup = ("./chpl_ta", Ta_inst:string, "_", lb_name, "_",
        ((1-branching)*"forward" + branching*"backward"), ".txt");
      return "".join(tup);
    }

    override proc help_message(): void
    {
      writeln("\n  PFSP Benchmark Parameters:\n");
      writeln("   --inst  int   Taillard instance (0-120)");
      writeln("   --lb    str   lower bound function (lb1, lb1_d, lb2)");
      writeln("   --br    int   branching rule (0: forward, 1: backward)");
      writeln("   --ub    str   upper bound initialization (opt, inf)\n");
    }

  } // end class

} // end module
