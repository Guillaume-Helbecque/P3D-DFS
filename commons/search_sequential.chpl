module search_sequential
{
  use List;
  use Time;

  use aux;
  use Problem;

  proc search_sequential(type Node, problem, const saveTime: bool): void
  {
    var best: int = problem.getInitBound();
    var best_at: atomic int = best;

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
        maxDepth, best_at, best);

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

    writeln("\n=================================================");
    writeln("Size of the explored tree: ", exploredTree);
    writeln("Number of explored solutions: ", exploredSol);
    writeln("Optimal makespan: ", best);
    writeln("Elapsed time: ", globalTimer.elapsed(), " [s]");
    writeln("=================================================\n");

    /* problem.print_results(exploredTree, exploredSol, maxDepth, best,
      globalTimer.elapsed()); */
  }
}
