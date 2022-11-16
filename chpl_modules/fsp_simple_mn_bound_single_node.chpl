module fsp_simple_mn_bound_single_node
{
  use List;
  use Time;
  use CTypes;
  use PrivateDist;
  use VisualDebug;
  use CommDiagnostics;
  use DistributedBag_DFS;

  use aux;
  use fsp_aux;
  use fsp_node;
  use statistics;
  use fsp_simple_chpl_c_headers;

  // Decompose a parent node and return the list of its feasible child nodes (SIMPLE O(MxN))
  proc decompose(const parent: Node, ref tree_loc: int, ref num_sol: int, const jobs: c_int, const machines: c_int,
    side: int, best: atomic int, ref best_task: int, const lb1_data: c_ptr(bound_data)): list
  {
    var childList: list(Node); // list containing the child nodes

    // Treatment of childs
    for i in parent.limit1+1..parent.limit2-1 {
      var child = new Node(parent);
      child.prmu[child.depth] <=> child.prmu[i]; // Chapel swap operator
      child.depth  += 1;
      child.limit1 += 1;

      var c_prmu: c_ptr(c_int) = tupleToCptr(child.prmu);

      var lowerbound: c_int = lb1_bound(lb1_data, c_prmu, child.limit1:c_int, jobs);

      c_free(c_prmu);

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

  proc fsp_simple_mn_search_single_node(const instance: int(8), const side: int,
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

    // Global variables (best solution found and termination)
    var best: atomic int = setOptimal(instance);
    var allTasksEmptyFlag: atomic bool = false;
    var eachTaskTermination: [0..#here.maxTaskPar] atomic bool = false;

    // Counters and timers (for analysis)
    var eachLocalExploredTree: [0..#here.maxTaskPar] int = 0;
    var eachLocalExploredSol: [0..#here.maxTaskPar] int = 0;
    var counter_termination: atomic int = 0;
    var timers: [0..#here.maxTaskPar, 0..4] real;
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

    var bag = new DistBag_DFS(Node, targetLocales = Locales);
    var root = new Node();

    if activeSet {
      /*
        An initial set is sequentially computed and distributed across locales.
        We require at least 2 nodes per task.
      */
      var initSize: int = 2 * here.maxTaskPar * numLocales;
      var initList: list(Node);
      initList.append(root);

      var best_task: int = best.read();

      // Computation of the initial set
      while (initList.size < initSize) {
        var parent: Node = initList.pop();

        {
          var childList: list(Node) = decompose(parent, eachLocalExploredTree[0], eachLocalExploredSol[0],
            jobs, machines, side, best, best_task, lb1_data);

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
        In that case, there is only one node in the bag (task 0 of locale 0).
      */
      bag.add(root, 0);
    }

    writeln("\nInitial state of the bag (locale x task):");
    for loc in Locales do on loc {
      writeln(bag.bag!.segments.nElems);
    }

    globalTimer.start();

    // =====================
    // PARALLEL EXPLORATION
    // =====================

    coforall tid in 0..#here.maxTaskPar {

      // Task variables (best solution found)
      var best_task: int = best.read();

      // Counters and timers (for analysis)
      var count, counter: int = 0;
      var terminationTimer, decomposeTimer, readTimer, removeTimer: Timer;

      // Exploration of the tree
      while true do {
        counter += 1;

        // Check if the global termination flag is set or not
        terminationTimer.start();
        if (counter % 10000 == 0) {
          if allTasksEmptyFlag.read() {
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
          Check (or not) the termination condition regarding the value of 'hasWork':
            'hasWork' = -1 : remove() fails              -> check termination
            'hasWork' =  0 : remove() prematurely fails  -> continue
            'hasWork' =  1 : remove() succeeds           -> decompose
        */

        terminationTimer.start();
        if (hasWork != 1) then eachTaskTermination[tid].write(true);
        else {
          eachTaskTermination[tid].write(false);
        }

        if (hasWork == -1) {
          if allTasksEmpty(eachTaskTermination, allTasksEmptyFlag) { // local check
            terminationTimer.stop();
            break;
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
            jobs, machines, side, best, best_task, lb1_data);

          bag.addBulk(childList, tid);
        }
        decomposeTimer.stop();

        // Read the best solution found so far
        readTimer.start();
        if (tid == 0) {
          count += 1;
          if (count % 10000 == 0) then best_task = best.read();
        }

        readTimer.stop();
      }

      timers[tid, 0] = tid;
      timers[tid, 1] = removeTimer.elapsed(TimeUnits.seconds);
      timers[tid, 2] = decomposeTimer.elapsed(TimeUnits.seconds);
      timers[tid, 3] = terminationTimer.elapsed(TimeUnits.seconds);
      timers[tid, 4] = readTimer.elapsed(TimeUnits.seconds);
    }

    globalTimer.stop();

    free_bound_data(lb1_data);
    /* bag.clear(); */

    // ========
    // OUTPUTS
    // ========

    writeln("Exploration terminated.\n");

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
      var tup = ("./ta",instance:string,"_chpl_",(+ reduce eachLocalExploredTree):string,"_",lb,".txt");
      var path = "".join(tup);
      /* save_time(numLocales:c_int, globalTimer.elapsed(TimeUnits.seconds):c_double, path.c_str()); */
      save_time(here.maxTaskPar:c_int, globalTimer.elapsed(TimeUnits.seconds):c_double, path.c_str());
    }

    if saveTime {
      var tup = ("./ta",instance:string,"_chpl_",(+ reduce eachLocalExploredTree):string,"_",lb,"_",numLocales:string,"n_subtimes.txt");
      var path = "".join(tup);
      save_subtimes(path, timers);
    }

    //writeln("\nNumber of global termination detection: ", counter_termination.read());
    print_results(eachLocalExploredTree, eachLocalExploredSol, globalTimer, best.read());
  }

}
