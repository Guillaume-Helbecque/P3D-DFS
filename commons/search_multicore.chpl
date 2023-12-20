module search_multicore
{
  use List;
  use Time;
  use DistributedBag_DFS;

  use aux;
  use Problem;

  const BUSY: bool = false;
  const IDLE: bool = true;

  proc search_multicore(type Node, problem, const saveTime: bool, const activeSet: bool): void
  {
    const numTasks = here.maxTaskPar;

    // Global variables (best solution found and termination)
    var best: atomic int = problem.getInitBound();
    var allTasksIdleFlag: atomic bool = false;
    var eachTaskState: [0..#numTasks] atomic bool = BUSY;

    // Statistics
    var eachExploredTree: [0..#numTasks] int;
    var eachExploredSol: [0..#numTasks] int;
    var eachMaxDepth: [0..#numTasks] int;
    var globalTimer: stopwatch;

    problem.print_settings();

    // ===============
    // INITIALIZATION
    // ===============

    var bag = new DistBag_DFS(Node);
    var root = new Node(problem);

    if activeSet {
      /*
        An initial set is sequentially computed and distributed across tasks.
        We require at least 2 elements per task.
      */
      var initSize: int = 2 * numTasks;
      var initList: list(Node);
      initList.pushBack(root);

      var best_task: int = best.read();
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

      // Static distribution of the set
      var seg: int;
      for elt in initList {
        bag.add(elt, seg);
        seg += 1;
        if (seg == numTasks) then seg = 0;
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

    coforall taskId in 0..#numTasks with (ref eachExploredTree, ref eachExploredSol,
      ref eachMaxDepth, ref eachTaskState) {

      // Task variables
      var best_task: int = best.read();
      var taskState: bool = BUSY;
      var counter: int = 0;
      ref tree_loc = eachExploredTree[taskId];
      ref num_sol = eachExploredSol[taskId];
      ref max_depth = eachMaxDepth[taskId];

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
            break;
          }
          continue;
        }

        // Decompose an element
        var children = problem.decompose(Node, parent, tree_loc, num_sol,
          max_depth, best, best_task);

        bag.addBulk(children, taskId);

        // Read the best solution found so far
        if (taskId == 0) {
          counter += 1;
          if (counter % 10000 == 0) then best_task = best.read();
        }

      }
    }

    globalTimer.stop();

    // ========
    // OUTPUTS
    // ========

    writeln("\nExploration terminated.");

    if saveTime {
      const path = problem.output_filepath();
      save_time(numTasks, globalTimer.elapsed(), path);
    }

    problem.print_results(eachExploredTree, eachExploredSol, eachMaxDepth, best.read(),
      globalTimer.elapsed());
  }
}
