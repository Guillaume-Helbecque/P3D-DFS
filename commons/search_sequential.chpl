module search_sequential
{
  use List;
  use Time;

  use util;
  use Problem;

  proc search_sequential(type Node, problem, const saveTime: bool): void
  {
    var bestCost: int = problem.getInitBound();
    var bestBound: int = if (problem.obj == "min") then max(int) else 0;

    /* Not needed in sequential mode, but we use it only to match the generic template. */
    var lockBestCost: sync bool = true;

    // Statistics
    var exploredTree: int;
    var exploredSol: int;
    var maxDepth: int;
    var globalTimer: stopwatch;

    problem.print_settings();

    // ===============
    // INITIALIZATION
    // ===============

    var pool: list(Node);
    var root = new Node(problem);

    pool.pushBack(root);

    globalTimer.start();

    // =====================
    // PARALLEL EXPLORATION
    // =====================

    // Exploration of the tree
    while !pool.isEmpty() do {

      // Remove an element
      var parent: Node = pool.popBack();

      // Decompose the element
      var children = problem.decompose(Node, parent, exploredTree, exploredSol,
        maxDepth, bestCost, lockBestCost, bestCost);

      pool.pushBack(children);
    }

    globalTimer.stop();

    // ========
    // OUTPUTS
    // ========

    writeln("\nExploration terminated.");

    if saveTime {
      const path = problem.output_filepath();
      save_time(1, globalTimer.elapsed(), path);
    }

    problem.print_results(exploredTree, exploredSol, maxDepth, bestCost, bestBound,
      globalTimer.elapsed());
  }
}
