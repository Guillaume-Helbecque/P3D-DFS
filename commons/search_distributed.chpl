module search_distributed
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
  use statistics;

  use Problem;

  const BUSY: bool = false;
  const IDLE: bool = true;

  proc search_distributed(type Node, problem,
    const dbgProfiler: bool, const dbgDiagnostics: bool,
    const saveTime: bool, const activeSet: bool): void
  {
    // Global variables (best solution found and termination)
    var best: atomic int = problem.setInitUB();
    const PrivateSpace: domain(1) dmapped Private(); // map each index to a locale
    var eachLocaleTermination: [PrivateSpace] atomic bool = BUSY;
    allLocalesBarrier.reset(here.maxTaskPar); // configuration of the global barrier

    // Counters and timers (for analysis)
    var eachExploredTree: [PrivateSpace] int = 0;
    var eachExploredSol: [PrivateSpace] int = 0;
    var eachMaxDepth: [PrivateSpace] int = 0;
    var counter_termination: atomic int = 0;
    var timers: [0..#numLocales, 0..#here.maxTaskPar, 0..5] real;
    var globalTimer: stopwatch;

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

      var best_task, best_locale: int = best.read();
      ref tree_loc = eachExploredTree[0];
      ref num_sol = eachExploredSol[0];

      // Computation of the initial set
      while (initList.size < initSize) {
        var parent: Node = initList.pop();

        {
          var children = problem.decompose(Node, parent, tree_loc, num_sol, best, best_task);

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

    coforall loc in Locales with (ref timers, const ref problem) do on loc {

      var problem_loc = problem.copy();

      // Local variables (best solution found and termination)
      var best_locale: int = problem.setInitUB();
      var allTasksEmptyFlag: atomic bool = false;
      var globalTerminationFlag: atomic bool = false;
      var eachTaskTermination: [0..#here.maxTaskPar] atomic bool = BUSY;

      // Counters and timers (for analysis)
      var eachLocalExploredTree: [0..#here.maxTaskPar] int = 0;
      var eachLocalExploredSol: [0..#here.maxTaskPar] int = 0;
      var localTimer: stopwatch;

      localTimer.start();

      coforall tid in 0..#here.maxTaskPar with (ref best_locale, ref timers) {

        // Task variables (best solution found)
        var best_task: int = best_locale;
        ref tree_loc = eachLocalExploredTree[tid];
        ref num_sol = eachLocalExploredSol[tid];

        // Counters and timers (for analysis)
        var count, counter: int = 0;
        var terminationTimer, decomposeTimer, readTimer, removeTimer: stopwatch;

        allLocalesBarrier.barrier(); // synchronization of tasks

        while true do {
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
            Check (or not) the termination condition regarding the value of 'hasWork':
              'hasWork' = -1 : remove() fails              -> check termination
              'hasWork' =  0 : remove() prematurely fails  -> continue
              'hasWork' =  1 : remove() succeeds           -> decompose
          */

          terminationTimer.start();
          if (hasWork != 1) then eachTaskTermination[tid].write(IDLE);
          else {
            eachTaskTermination[tid].write(BUSY);
            eachLocaleTermination[here.id].write(BUSY);
          }

          if (hasWork == -1) {
            if allTasksEmpty(eachTaskTermination, allTasksEmptyFlag) { // local check
              eachLocaleTermination[here.id].write(IDLE);

                if allLocalesEmpty(eachLocaleTermination, globalTerminationFlag, counter_termination) { // global check
                  terminationTimer.stop();
                  break;
                }

            } else {
              eachLocaleTermination[here.id].write(BUSY);
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
            var children = problem_loc.decompose(Node, parent, tree_loc, num_sol, best, best_task);

            bag.addBulk(children, tid);
          }
          decomposeTimer.stop();

          // Read the best solution found so far
          readTimer.start();
          if (tid == 0) {
            count += 1;
            if (count % 10000 == 0) then best_locale = best.read();
          }

          best_task = best_locale;
          readTimer.stop();
        }

        timers[loc.id, tid, 0] = loc.id;
        timers[loc.id, tid, 1] = tid;
        timers[loc.id, tid, 2] = removeTimer.elapsed(TimeUnits.seconds);
        timers[loc.id, tid, 3] = decomposeTimer.elapsed(TimeUnits.seconds);
        timers[loc.id, tid, 4] = terminationTimer.elapsed(TimeUnits.seconds);
        timers[loc.id, tid, 5] = readTimer.elapsed(TimeUnits.seconds);
      } // end coforall tasks

      localTimer.stop();

      eachExploredTree[here.id] += (+ reduce eachLocalExploredTree);
      eachExploredSol[here.id] += (+ reduce eachLocalExploredSol);
    } // end coforall locales

    globalTimer.stop();

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
      var path = problem.output_filepath();
      save_time(numLocales:c_int, globalTimer.elapsed(TimeUnits.seconds):c_double, path.c_str());
    }

    /* if saveTime {
      var tup = ("./ta",instance:string,"_chpl_",(+ reduce eachExploredTree):string,"_",lb,"_",numLocales:string,"n_subtimes.txt");
      var path = "".join(tup);
      save_subtimes(path, timers);
    } */

    //writeln("\nNumber of global termination detection: ", counter_termination.read());
    problem.print_results(eachExploredTree, eachExploredSol, eachMaxDepth, best.read(), globalTimer);
  }

}
