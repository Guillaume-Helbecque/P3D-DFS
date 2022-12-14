module main_pfsp
{
  // Common modules
  use CTypes;

  use aux;
  use Problem;
  use search_multicore;
  use search_distributed;

  // PFSP-specific modules
  use Node_PFSP;
  use Problem_PFSP;

  // Common options
  config const mode: string = "multicore"; // multicore, distributed
  config const dbgProfiler: bool = false;
  config const dbgDiagnostics: bool = false;
  config const activeSet: bool = false;
  config const saveTime: bool = false;
  /* config const printExploredTree: bool = true; // number of explored nodes
  config const printExploredSol: bool = true; // number of explored solutions
  config const printMakespan: bool = true; // best makespan */

  // PFSP-specific options
  config const inst: c_int = 14;     // between 1 and 120
  config const lb: string = "lb1";  // lb1, lb1_d, lb2
  config const br: int = 0;         // forward (0), backward (1)
  config const ub: string = "opt";  // opt, inf

  proc main(args: [] string): int
  {
    // Initialization of the problem
    var pfsp = new Problem_PFSP(inst, lb, br, ub);

    // Helper
    for a in args[1..] {
      if (a == "-h" || a == "--help") {
        common_help_message();
        pfsp.help_message();

        return 1;
      }
    }

    // Parallel search
    select mode {
      when "multicore" {
        search_multicore(Node_PFSP, pfsp, dbgProfiler, dbgDiagnostics, saveTime, activeSet);
      }
      when "distributed" {
        search_distributed(Node_PFSP, pfsp, dbgProfiler, dbgDiagnostics, saveTime, activeSet);
      }
      otherwise {
        halt("ERROR - Unknown parallel execution mode");
      }
    }

    return 0;
  }
}
