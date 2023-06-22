module search_distributed
{
  use List;
  use Time;
  use CTypes;
  use PrivateDist;
  use DistributedBag_DFS;
  use AllLocalesBarriers;

  use aux;
  use Problem;

  const BUSY: bool = false;
  const IDLE: bool = true;

  proc search_distributed(type Node, problem, const saveTime: bool, const activeSet: bool): void
  {
    // Global variables (best solution found and termination)
    var best: atomic int = problem.setInitUB();
    const PrivateSpace: domain(1) dmapped Private(); // map each index to a locale
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

    var bag = new DistBag_DFS(Node, targetLocales = Locales);
    var root = new Node(problem);

    if activeSet {
      /*
        An initial set is sequentially computed and distributed across locales.
        We require at least 2 nodes per task.
      */
      var initSize: int = 2 * here.maxTaskPar * numLocales;
      var initList: list(Node);
      initList.pushBack(root);

      var best_task, best_locale: int = best.read();
      ref tree_loc = eachExploredTree[0];
      ref num_sol = eachExploredSol[0];
      ref max_depth = eachMaxDepth[0];

      // Computation of the initial set
      while (initList.size < initSize) {
        var parent = initList.popBack();

        {
          var children = problem.decompose(Node, parent, tree_loc, num_sol,
            max_depth, best, best_task);

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

      initList.clear();
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

    coforall loc in Locales with (const ref problem) do on loc {

      var numTasks = here.maxTaskPar;
      var problem_loc = problem.copy();

      // Local variables
      var best_locale: int = problem.setInitUB();
      var allTasksIdleFlag: atomic bool = false;
      var eachTaskState: [0..#numTasks] atomic bool = BUSY;

      // Local statistics
      var eachLocalExploredTree: [0..#numTasks] int;
      var eachLocalExploredSol: [0..#numTasks] int;
      var eachLocalMaxDepth: [0..#numTasks] int;

      coforall taskId in 0..#numTasks with (ref best_locale) {

        // Task variables
        var best_task: int = best_locale;
        var taskState, locState: bool = false;
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
              taskState = false;
              eachTaskState[taskId].write(BUSY);
            }
            if locState {
              locState = false;
              eachLocaleState[here.id].write(BUSY);
            }
          }
          else if (hasWork == 0) {
            if !taskState {
              taskState = true;
              eachTaskState[taskId].write(IDLE);
            }
            continue;
          }
          else {
            if !taskState {
              taskState = true;
              eachTaskState[taskId].write(IDLE);
            }
            if allIdle(eachTaskState, allTasksIdleFlag) {
              if !locState {
                locState = true;
                eachLocaleState[here.id].write(IDLE);
              }
              if allIdle(eachLocaleState, allLocalesIdleFlag) {
                break;
              }
            } else {
              if locState {
                locState = false;
                eachLocaleState[here.id].write(BUSY);
              }
            }
            continue;
          }

          // Decompose an element
          var children = problem_loc.decompose(Node, parent, tree_loc, num_sol,
            max_depth, best, best_task);

          bag.addBulk(children, taskId);

          // Read the best solution found so far
          if (taskId == 0) {
            counter += 1;
            if (counter % 10000 == 0) then best_locale = best.read();
          }

          best_task = best_locale;
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
      var path = problem.output_filepath();
      save_time(numLocales:c_int, globalTimer.elapsed():c_double, path.c_str());
    }

    problem.print_results(eachExploredTree, eachExploredSol, eachMaxDepth, best.read(), globalTimer);
  }

}
