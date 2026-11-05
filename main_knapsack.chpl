module main_knapsack
{
  use commons;

  // Problem-specific modules
  use Node_Knapsack;
  use Problem_Knapsack;

  // Problem-specific option
  config const inst: string = "knapPI_1_100_10000_1";
  config const ub: string   = "dantzig"; // dantzig, martello
  config const lb: string   = "heuristic"; // opt, heuristic
  config const mb: int      = 1; // multi-variable branching factor

  proc main(args: [] string): int
  {
    // initialize problem instance
    var knapsack = new Problem_Knapsack(inst, ub, lb);
    // initialize root node
    var root = new Node_Knapsack();

    // launch B&B search
    run_search(args, root, knapsack);

    return 0;
  }
}
