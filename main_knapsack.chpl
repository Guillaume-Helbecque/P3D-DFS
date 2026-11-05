module main_knapsack
{
  use CTypes;

  // Common modules
  use util;
  use search_sequential;
  use search_multicore;
  use search_distributed;

  // Problem-specific modules
  use Node_Knapsack;
  use Problem_Knapsack;

  // Common options
  config const mode: string    = "multicore"; // sequential, multicore, distributed
  config const findAll: bool   = false;
  config const activeSet: bool = false;
  config const saveTime: bool  = false;

  // Problem-specific option
  config const inst: string = "knapPI_1_100_10000_1";
  config const ub: string   = "dantzig"; // dantzig, martello
  config const lb: string   = "heuristic"; // opt, heuristic
  config const mb: int      = 1; // multi-variable branching factor

  proc main(args: [] string): int
  {
    // Initialization of the problem
    var knapsack = new Problem_Knapsack(inst, ub, lb);

    // Helper
    for a in args[1..] {
      if (a == "-h" || a == "--help") {
        common_help_message(args[0]);
        knapsack.help_message();

        return 1;
      }
    }

    // Search
    select mode {
      when "sequential" {
        if activeSet then warning("`activeSet` is ignored in sequential mode");
        search_sequential(Node_Knapsack, knapsack, saveTime);
      }
      when "multicore" {
        search_multicore(Node_Knapsack, knapsack, saveTime, activeSet);
      }
      when "distributed" {
        search_distributed(Node_Knapsack, knapsack, saveTime, activeSet);
      }
      otherwise {
        halt("unknown execution mode");
      }
    }

    return 0;
  }
}
