module search_sequential
{
  use List;
  use Time;

  use util;
  use Problem;

  proc search_sequential(type Node, problem, const timelimit: real, const saveTime: bool): void
  {
    var status: solverStatus = solverStatus.optimal;
    var best: int = problem.getInitBound();
    var bestBound: real;
    /* Not needed in sequential mode, but we use it only to match the generic template. */
    var lockBest: sync bool = true;

    // Statistics
    var exploredTree, exploredSol, maxDepth: int;
    var globalTimer: stopwatch;

    writeln("Sequential execution mode");
    problem.print_settings();

    globalTimer.start();

    // ===============
    // INITIALIZATION
    // ===============

    var pool: list(Node);
    var root = new Node(problem);

    pool.pushBack(root);

    // ============
    // EXPLORATION
    // ============

    // Exploration of the tree
    while !pool.isEmpty() do {

      // Remove an element
      var parent: Node = pool.popBack();

      // Decompose the element
      var children = problem.decompose(Node, parent, exploredTree, exploredSol,
        maxDepth, best, lockBest, best);

      pool.pushBack(children);
    }

    globalTimer.stop();

    if !exploredSol && status != solverStatus.timelimit {
      status = solverStatus.infeasible;
    }

    // ========
    // OUTPUTS
    // ========

    writeln("\nExploration terminated.");

    if saveTime {
      const path = problem.output_filepath();
      save_time(1, globalTimer.elapsed(), path);
    }

    problem.print_results(status, exploredTree, exploredSol, maxDepth, best,
      bestBound, globalTimer.elapsed());
  }
}
