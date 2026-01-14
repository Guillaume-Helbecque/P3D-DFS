module search_sequential
{
  use IO;
  use List;
  use Time;

  use util;
  use Problem;

  import main_knapsack.t as tt;
  import main_knapsack.id as id;
  import Problem_Knapsack.MB as MB;

  config const filepath = "";

  proc search_sequential(type Node, problem, const saveTime: bool): void
  {
    var best: int = problem.getInitBound();
    /* Not needed in sequential mode, but we use it only to match the generic template. */
    var lockBest: sync bool = true;

    // Statistics
    var exploredTree: int;
    var exploredSol: int;
    var maxDepth: int;
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

    // ========
    // OUTPUTS
    // ========

    writeln("\nExploration terminated.");

    try! {
      var f: file = open(filepath, ioMode.a);
      var channel = f.writer(locking=false);
      channel.writeln("knapPI_", tt, "_", problem.N, "_1000_", id, "\t", MB, "\t", best, "\t", exploredSol,
        "\t", globalTimer.elapsed(), "\t", exploredTree, "\t", maxDepth);
      channel.close();
      f.close();
    }

    /* if saveTime {
      const path = problem.output_filepath();
      save_time(1, globalTimer.elapsed(), path);
    } */

    problem.print_results(exploredTree, exploredSol, maxDepth, best,
      globalTimer.elapsed());
  }
}
