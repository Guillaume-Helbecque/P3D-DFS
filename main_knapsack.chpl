module main_knapsack
{
  // Common modules
  use util;
  use search_sequential;
  use search_multicore;
  use search_distributed;

  // Knapsack-specific modules
  use Node_Knapsack;
  use Problem_Knapsack;

  // Common options
  config const mode: string    = "multicore"; // sequential, multicore, distributed
  config const activeSet: bool = false;
  config const saveTime: bool  = false;

  // Knapsack-specific option
  config const inst: string = "default.txt";
  config const lb: string   = "opt"; // opt, inf

  proc main(args: [] string): int
  {
    // Initialization of the problem
    var knapsack = new Problem_Knapsack(inst, lb);

    // Helper
    for a in args[1..] {
      if (a == "-h" || a == "--help") {
        common_help_message();
        knapsack.help_message();

        return 1;
      }
    }

    // Search
    select mode {
      when "sequential" {
        if activeSet then warning("Cannot use `activeSet` in sequential mode.");
        search_sequential(Node_Knapsack, knapsack, saveTime);
      }
      when "multicore" {
        search_multicore(Node_Knapsack, knapsack, saveTime, activeSet);
      }
      when "distributed" {
        search_distributed(Node_Knapsack, knapsack, saveTime, activeSet);
      }
      otherwise {
        halt("ERROR - Unknown execution mode");
      }
    }

    return 0;
  }
}
