module search_distributed
{
  use List;
  use Time;
  use PrivateDist;
  use DistributedBag_DFS;
  use AllLocalesBarriers;

  use util;
  use Problem;

  proc search_distributed(type Node, problem, const saveTime: bool, const activeSet: bool): void
  {
    // Global variables (best cost found and termination)
    var bestCost: int = problem.getInitBound();
    var bestBound: int = if (problem.obj == "min") then max(int) else 0;
    var lockBestCost: sync bool = true;
    var eachLocaleState: [PrivateSpace] atomic bool = BUSY;
    var allLocalesIdleFlag: atomic bool = false;
    allLocalesBarrier.reset(here.maxTaskPar); // configuration of the global barrier

    // Statistics
    var eachExploredTree: [PrivateSpace] int;
    var eachExploredSol: [PrivateSpace] int;
    var eachMaxDepth: [PrivateSpace] int;
    var globalTimer: stopwatch;

    problem.print_settings();

    // ===============
    // INITIALIZATION
    // ===============

    var bag = new distBag_DFS(Node, targetLocales = Locales);
    var root = new Node(problem);

    if activeSet {
      /*
        An initial set is sequentially computed and distributed across locales.
        We require at least 2 elements per task.
      */
      var initSize: int = 2 * here.maxTaskPar * numLocales;
      var initList: list(Node);
      initList.pushBack(root);

      var bestCost_task: int = bestCost;
      ref tree_loc = eachExploredTree[0];
      ref num_sol = eachExploredSol[0];
      ref max_depth = eachMaxDepth[0];

      // Computation of the initial set
      while (initList.size < initSize) {
        var parent = initList.popBack();

        {
          var children = problem.decompose(Node, parent, tree_loc, num_sol,
            max_depth, bestCost, lockBestCost, bestCost_task);

          for elt in children do initList.insert(0, elt);
        }
      }

      // Static distribution of the initial set
      var seg, loc: int;
      for elt in initList {
        on Locales[loc % numLocales] do bag.add(elt, seg);
        loc += 1;
        if (loc % numLocales == 0) {
          loc = loc % numLocales;
          seg += 1;
        }
        if (seg == here.maxTaskPar) then seg = 0;
      }
    }
    else {
      /*
        In that case, there is only one node in the bag (task 0 of locale 0).
      */
      bag.add(root, 0);
    }

    globalTimer.start();

    // =====================
    // PARALLEL EXPLORATION
    // =====================

    coforall loc in Locales with (const ref problem, ref eachLocaleState, ref eachExploredTree,
      ref eachExploredSol, ref eachMaxDepth, ref bestCost) do on loc {

      const numTasks = here.maxTaskPar;
      var problem_loc = problem.copy();

      // Local variables
      /* var bestCost_locale: int = bestCost; */
      var allTasksIdleFlag: atomic bool = false;
      var eachTaskState: [0..#numTasks] atomic bool = BUSY;

      // Local statistics
      var eachLocalExploredTree: [0..#numTasks] int;
      var eachLocalExploredSol: [0..#numTasks] int;
      var eachLocalMaxDepth: [0..#numTasks] int;

      coforall taskId in 0..#numTasks with (ref eachLocalExploredTree, ref eachLocalExploredSol,
        ref eachLocalMaxDepth, ref eachTaskState, ref eachLocaleState, ref bestCost/*, ref bestCost_locale*/) {

        // Task variables
        var bestCost_task: int = bestCost; //_locale;
        var taskState, locState: bool = BUSY;
        var counter: int = 0;
        ref tree_loc = eachLocalExploredTree[taskId];
        ref num_sol = eachLocalExploredSol[taskId];
        ref max_depth = eachLocalMaxDepth[taskId];

        allLocalesBarrier.barrier(); // synchronization barrier

        // Exploration of the tree
        while true do {

          // Try to remove an element
          var (hasWork, parent): (int, Node) = bag.remove(taskId);

          /*
            Check (or not) the termination condition regarding the value of 'hasWork':
              'hasWork' = -1 : remove() fails              -> check termination
              'hasWork' =  0 : remove() prematurely fails  -> continue
              'hasWork' =  1 : remove() succeeds           -> decompose
          */
          if (hasWork == 1) {
            if taskState {
              taskState = BUSY;
              eachTaskState[taskId].write(BUSY);
            }
            if locState {
              locState = BUSY;
              eachLocaleState[here.id].write(BUSY);
            }
          }
          else if (hasWork == 0) {
            if !taskState {
              taskState = IDLE;
              eachTaskState[taskId].write(IDLE);
            }
            continue;
          }
          else {
            if !taskState {
              taskState = IDLE;
              eachTaskState[taskId].write(IDLE);
            }
            if allIdle(eachTaskState, allTasksIdleFlag) {
              if !locState {
                locState = IDLE;
                eachLocaleState[here.id].write(IDLE);
              }
              if allIdle(eachLocaleState, allLocalesIdleFlag) {
                break;
              }
            }
            continue;
          }

          // Decompose an element
          var children = problem_loc.decompose(Node, parent, tree_loc, num_sol,
            max_depth, bestCost, lockBestCost, bestCost_task);

          bag.addBulk(children, taskId);

          // Read the best cost found so far
          /* if (taskId == 0) {
            counter += 1;
            if (counter % 10000 == 0) then bestCost_locale = bestCost.read();
          }

          bestCost_task = bestCost_locale; */
        }
      } // end coforall tasks

      eachExploredTree[here.id] += (+ reduce eachLocalExploredTree);
      eachExploredSol[here.id] += (+ reduce eachLocalExploredSol);
      eachMaxDepth[here.id] = (maxloc reduce zip(eachLocalMaxDepth, eachLocalMaxDepth.domain))[0];
    } // end coforall locales

    globalTimer.stop();

    // ========
    // OUTPUTS
    // ========

    writeln("\nExploration terminated.");

    if saveTime {
      const path = problem.output_filepath();
      save_time(numLocales, globalTimer.elapsed(), path);
    }

    problem.print_results(eachExploredTree, eachExploredSol, eachMaxDepth, bestCost,
      globalTimer.elapsed());
  }

}
