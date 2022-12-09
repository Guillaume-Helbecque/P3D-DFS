module search_multicore
{
  use List;
  use Time;
  use CTypes;
  use PrivateDist;
  use VisualDebug;
  use CommDiagnostics;
  use DistributedBag_DFS;

  use aux;
  use statistics;

  use Problem;

  const BUSY: bool = false;
  const IDLE: bool = true;

  proc search_multicore(type Node, problem,
    const dbgProfiler: bool, const dbgDiagnostics: bool,
    const saveTime: bool, const activeSet: bool): void
  {
    // Global variables (best solution found and termination)
    var best: atomic int = problem.setInitUB();
    var allTasksEmptyFlag: atomic bool = false;
    var eachTaskTermination: [0..#here.maxTaskPar] atomic bool = BUSY;

    // Counters and timers (for analysis)
    var eachLocalExploredTree: [0..#here.maxTaskPar] int = 0;
    var eachLocalExploredSol: [0..#here.maxTaskPar] int = 0;
    var eachMaxDepth: [0..#here.maxTaskPar] int = 0;
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

    problem.print_settings();

    // ===============
    // INITIALIZATION
    // ===============

    var bag = new DistBag_DFS(Node, targetLocales = Locales);
    var root = new Node(problem);

    if activeSet {
      /*
        An initial set is sequentially computed and distributed across locales.
        We require at least 2 nodes per task.
      */
      var initSize: int = 2 * here.maxTaskPar * numLocales;
      var initList: list(Node);
      initList.append(root);

      var best_task: int = best.read();
      ref tree_loc = eachLocalExploredTree[0];
      ref num_sol = eachLocalExploredSol[0];

      // Computation of the initial set
      while (initList.size < initSize) {
        var parent: Node = initList.pop();

        {
          var children = problem.decompose(Node, parent, tree_loc, num_sol,
            best, best_task);

          for elt in children do initList.insert(0, elt);
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
      ref tree_loc = eachLocalExploredTree[tid];
      ref num_sol = eachLocalExploredSol[tid];

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
        if (hasWork != 1) then eachTaskTermination[tid].write(IDLE);
        else {
          eachTaskTermination[tid].write(BUSY);
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
          var children = problem.decompose(Node, parent, tree_loc, num_sol, best, best_task);

          bag.addBulk(children, tid);
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
      var path = problem.output_filepath();
      save_time(here.maxTaskPar:c_int, globalTimer.elapsed(TimeUnits.seconds):c_double, path.c_str());
    }

    /* if saveTime {
      var tup = ("./ta",pfsp.Ta_inst:string,"_chpl_",(+ reduce eachLocalExploredTree):string,"_",lb,"_",numLocales:string,"n_subtimes.txt");
      var path = "".join(tup);
      save_subtimes(path, timers);
    } */

    //writeln("\nNumber of global termination detection: ", counter_termination.read());
    problem.print_results(eachLocalExploredTree, eachLocalExploredSol, eachMaxDepth, best.read(), globalTimer);
  }

}
