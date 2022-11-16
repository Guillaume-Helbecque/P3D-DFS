module fsp_johnson_bound_multi_node
{
  use List;
  use Time;
  use CTypes;
  use PrivateDist;
  use VisualDebug;
  use CommDiagnostics;
  use DistributedBag_DFS;
  use AllLocalesBarriers;

  use aux;
  use fsp_aux;
  use fsp_node;
  use statistics;
  use fsp_johnson_chpl_c_headers;

  // Decompose a parent node and return the list of its feasible child nodes
  proc decompose(parent: Node, ref local_tree: int, ref num_sol: int, const jobs: c_int, const machines: c_int,
    best: atomic int, ref best_locale: int, ref best_tasks: int, const lb1_data: c_ptr(bound_data),
    const lb2_data: c_ptr(johnson_bd_data)): list
  {
    var childList: list(Node); // list containing the child nodes

    for i in parent.limit1+1..parent.limit2-1 {
      var child = new Node(parent);
      child.prmu[child.depth] <=> child.prmu[i]; // Chapel swap operator
      child.depth  += 1;
      child.limit1 += 1;

      var c_prmu: c_ptr(c_int) = tupleToCptr(child.prmu);

      var lowerbound: c_int = lb2_bound(lb1_data, lb2_data, c_prmu, child.limit1:c_int, jobs, best_tasks:c_int);

      c_free(c_prmu);

      if (child.depth == jobs) { // if child leaf
        num_sol += 1;

        if (lowerbound < best_tasks) { // if child feasible
          best_locale = best_tasks;
          best.write(lowerbound);
        }
      } else { // if not leaf
        if (lowerbound < best_tasks) { // if child feasible
          local_tree += 1;
          childList.append(child);
        }
      }

    }

    return childList;
  }

  proc fsp_johnson_search_multi_node(const instance: int(8), const side: int,
    const dbgProfiler: bool, const dbgDiagnostics: bool, const printExploredTree: bool,
    const printExploredSol: bool, const printMakespan: bool, const lb: string,
    const saveTime: bool, const activeSet: bool): void
  {
    // FSP data
    var jobs: c_int = taillard_get_nb_jobs(instance);
    var machines: c_int = taillard_get_nb_machines(instance);

    var lb1_data: c_ptr(bound_data) = new_bound_data(jobs, machines);
    taillard_get_processing_times_d(lb1_data, instance);
    fill_min_heads_tails(lb1_data);

    var lb2_data: c_ptr(johnson_bd_data) = new_johnson_bd_data(lb1_data/*, LB2_FULL*/);

    fill_machine_pairs(lb2_data/*, LB2_FULL*/);
    fill_lags(lb1_data, lb2_data);
    fill_johnson_schedules(lb1_data, lb2_data);

    // Global variables (best solution found and termination)
    var best: atomic int = setOptimal(instance);
    const PrivateSpace: domain(1) dmapped Private();
    var eachLocaleTermination: [PrivateSpace] atomic bool = false;
    allLocalesBarrier.reset(here.maxTaskPar);

    // Counters and timers (for analysis)
    var eachExploredTree: [PrivateSpace] int = 0;
    var eachExploredSol: [PrivateSpace] int = 0;
    var counter_termination: atomic int = 0;
    var timers: [0..#numLocales, 0..#here.maxTaskPar, 0..5] real;
    var globalTimer: Timer;

    // Debugging options
    if dbgProfiler {
      startVdebug("test");
      tagVdebug("init");
      writeln("Starting profiler");
    }

    if dbgDiagnostics {
      writeln("\n### Starting communication counter ###");
      startCommDiagnostics();
    }

    //print_instance(machines, jobs, times);
    print_settings(instance, best.read(), lb, side);

    // ===============
    // INITIALIZATION
    // ===============

    var bag = new DistBag_DFS(Node, targetLocales=Locales);
    var root = new Node();

    if activeSet {
      /*
        An initial set is sequentially computed and distributed across locales.
        We require at least 2 nodes per tasks.
      */
      var initSize: int = 2 * here.maxTaskPar * numLocales;
      var initList: list(Node);
      initList.append(root);

      var best_t, best_l: int = best.read();

      // Computation of the initial set
      while (initList.size < initSize) {
        var parent: Node = initList.pop();

        {
          var childList: list(Node) = decompose(parent, eachExploredTree[0], eachExploredSol[0],
            jobs, machines, best, best_l, best_t, lb1_data, lb2_data);

          for elt in childList do initList.insert(0, elt);
        }
      }

      // Static distribution of the set
      var seg: int = 0;
      var loc: int = 0;
      for elt in initList {
        on Locales[loc % numLocales] do bag.add(elt, seg);
        loc += 1;
        if (loc % numLocales == 0) {
          loc = loc % numLocales;
          seg += 1;
        }
        if (seg == here.maxTaskPar) then seg = 0;
      }

      initList.clear();
    }
    else {
      /*
        In that case, there is only one node in the bag (tasks 0 of locale 0).
      */
      bag.add(root, 0);
    }

    writeln("\nInitial state of the bag (locale x tasks):");
    for loc in Locales do on loc {
      writeln(bag.bag!.segments.nElems);
    }

    globalTimer.start();

    // =====================
    // PARALLEL EXPLORATION
    // =====================

    coforall loc in Locales with (ref timers, const jobs, const machines, const instance) do on loc {

      var lb1_data: c_ptr(bound_data) = new_bound_data(jobs, machines);
      taillard_get_processing_times_d(lb1_data, instance);
      fill_min_heads_tails(lb1_data);

      var lb2_data: c_ptr(johnson_bd_data) = new_johnson_bd_data(lb1_data/*, LB2_FULL*/);

      fill_machine_pairs(lb2_data/*, LB2_FULL*/);
      fill_lags(lb1_data, lb2_data);
      fill_johnson_schedules(lb1_data, lb2_data);

      // Local variables (best solution found and termination)
      var best_locale: int = setOptimal(instance);
      var allTasksEmptyFlag: atomic bool = false;
      var globalTerminationFlag: atomic bool = false;
      var eachTaskTermination: [0..#here.maxTaskPar] atomic bool = false;

      // Counters and timers (for analysis)
      var eachLocalExploredTree: [0..#here.maxTaskPar] int = 0;
      var eachLocalExploredSol: [0..#here.maxTaskPar] int = 0;
      var localTimer: Timer;

      localTimer.start();

      coforall tid in 0..#here.maxTaskPar with (ref best_locale, ref timers) {

        // Task variables (best solution found)
        var best_task: int = best_locale;

        // Counters and timers (for analysis)
        var count, counter: int = 0;
        var terminationTimer, decomposeTimer, readTimer, removeTimer: Timer;

        allLocalesBarrier.barrier(); // synchronization of tasks

        while true {
          counter += 1;

          // Check if the global termination flag is set or not
          terminationTimer.start();
          if (counter % 10000 == 0) {
            if globalTerminationFlag.read() {
              //writeln("loc/task ", here.id, " ", tid, " breaks");
              terminationTimer.stop();
              break;
            }
          }
          terminationTimer.stop();

          // Try to remove an element
          removeTimer.start();
          var (hasWork, parent): (int, Node) = bag.remove(tid);
          removeTimer.stop();

          /*
            Regarding the value of 'hasWork', 3 cases are distinguished:
            'hasWork' = -1 : remove() fails              -> check termination
            'hasWork' =  0 : remove() prematurely fails  -> do nothing
            'hasWork' =  1 : remove() succeeds           -> decompose
          */

          terminationTimer.start();
          if (hasWork != 1) then eachTaskTermination[tid].write(true);
          else {
            eachTaskTermination[tid].write(false);
            eachLocaleTermination[here.id].write(false);
          }

          if (hasWork == -1) {
            if allTasksEmpty(eachTaskTermination, allTasksEmptyFlag) { // local check
              eachLocaleTermination[here.id].write(true);

                if allLocalesEmpty(eachLocaleTermination, globalTerminationFlag, counter_termination) { // global check
                  terminationTimer.stop();
                  break;
                }

            } else {
              eachLocaleTermination[here.id].write(false);
            }
          terminationTimer.stop();
          continue;
          }
          else if (hasWork == 0) {
            terminationTimer.stop();
            continue;
          }
          terminationTimer.stop();

          // Decompose an element
          decomposeTimer.start();
          {
            var childList: list(Node) = decompose(parent, eachLocalExploredTree[tid], eachLocalExploredSol[tid],
              jobs, machines, best, best_locale, best_task, lb1_data, lb2_data);

            bag.addBulk(childList, tid);
          }
          decomposeTimer.stop();

          // Read the best solution found so far
          readTimer.start();
          // update globaly the best makespan found so far
          if (tid == 0) {
            count += 1;
            if (count % 10000 == 0) then best_locale = best.read();
          }

          // update locally the best makespan found so far
          best_task = best_locale;
          readTimer.stop();
        }

        timers[loc.id, tid, 0] = loc.id;
        timers[loc.id, tid, 1] = tid;
        timers[loc.id, tid, 3] = decomposeTimer.elapsed(TimeUnits.seconds);
        timers[loc.id, tid, 4] = terminationTimer.elapsed(TimeUnits.seconds);
        timers[loc.id, tid, 2] = removeTimer.elapsed(TimeUnits.seconds);
        timers[loc.id, tid, 5] = readTimer.elapsed(TimeUnits.seconds);
      } // end coforall tasks

      localTimer.stop();

      eachExploredTree[here.id] += (+ reduce eachLocalExploredTree);
      eachExploredSol[here.id] += (+ reduce eachLocalExploredSol);
    } // end coforall locales

    globalTimer.stop();

    free_bound_data(lb1_data);
    free_johnson_bd_data(lb2_data);
    //bag.clear();

    // ========
    // OUTPUTS
    // ========

    writeln("\nExploration terminated.");

    // Debugging options
    if dbgProfiler {
      stopVdebug();
      writeln("### Debuging is done ###");
    }

    if dbgDiagnostics {
      writeln("### Stopping communication counter ###");
      stopCommDiagnostics();
      writeln("\n ### Communication results ### \n", getCommDiagnostics());
    }

    if saveTime {
      var tup = ("./ta",instance:string,"_chpl_",(+ reduce eachExploredTree):string,"_",lb,"_dist.txt");
      var path = "".join(tup);
      /* save_time(here.maxTaskPar:c_int, globalTimer.elapsed(TimeUnits.seconds):c_double, path.c_str()); */
      save_time(numLocales:c_int, globalTimer.elapsed(TimeUnits.seconds):c_double, path.c_str());
    }

    if saveTime {
      var tup = ("./ta",instance:string,"_chpl_",(+ reduce eachExploredTree):string,"_",lb,"_",numLocales:string,"n_subtimes.txt");
      var path = "".join(tup);
      save_subtimes(path, timers);
    }

    //writeln("Number of global termination detection: ", counter_termination.read());
    print_results(eachExploredTree, eachExploredSol, globalTimer, best.read());
  }
}
