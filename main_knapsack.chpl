module main_knapsack
{
  use commons;

  // Problem-specific modules
  use Node_Knapsack;
  use Problem_Knapsack;

  // Problem-specific option
  config const inst: string = "";
  config const ub: string   = "dantzig"; // dantzig, martello
  config const lb: string   = "heuristic"; // opt, heuristic
  config const mb: int      = 1; // multi-variable branching factor

  use CTypes;
  config const n: c_int  = 100;
  config const r: c_int  = 10000;
  config const t: c_int  = 1;
  config const id: c_int = 1;
  config const s: c_int  = 100;

  proc main(args: [] string): int
  {
    // initialize problem instance
    var knapsack = new Problem_Knapsack(inst, n, r, t, id, s, ub, lb);
    // initialize root node
    var root = new Node_Knapsack();

    // launch B&B search
    run_search(args, root, knapsack);

    return 0;
  }
}
