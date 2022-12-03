module main_queens
{
  // Common modules
  use CTypes;

  use aux;
  use Problem;
  use search_multicore;
  use search_distributed;

  // NQueens-specific modules
  use Node_NQueens;
  use Problem_NQueens;

  // Common options
  config const mode: string = "multicore"; // multicore, distributed
  config const dbgProfiler: bool = false;
  config const dbgDiagnostics: bool = false;
  config const activeSet: bool = false;
  config const saveTime: bool = false;
  /* config const printExploredTree: bool = true; // number of explored nodes
  config const printExploredSol: bool = true; // number of explored solutions
  config const printMakespan: bool = true; // best makespan */

  // NQueens-specific options
  config const N: int = 8;

  proc main(args: [] string): int
  {
    // Initialization of the problem
    var nqueens: Problem = new NQueens(N);

    // Helper
    for a in args[1..] {
      if (a == "-h" || a == "--help") {
        common_help_message();
        nqueens.help_message();

        return 1;
      }
    }

    // Parallel search
    select mode {
      when "multicore" {
        search_multicore(Node_NQueens, nqueens, dbgProfiler, dbgDiagnostics, saveTime, activeSet);
      }
      when "distributed" {
        search_distributed(Node_NQueens, nqueens, dbgProfiler, dbgDiagnostics, saveTime, activeSet);
      }
      otherwise {
        halt("ERROR - Unknown parallel execution mode");
      }
    }

    return 0;
  }
}
