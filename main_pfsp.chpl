module main_pfsp
{
  // Common modules
  use util;
  use search_sequential;
  use search_multicore;
  use search_distributed;

  // PFSP-specific modules
  use Node_PFSP;
  use Problem_PFSP;

  // Common options
  config const mode: string    = "multicore"; // sequential, multicore, distributed
  config const activeSet: bool = false;
  config const saveTime: bool  = false;

  // PFSP-specific options
  config const inst: string = "ta14"; // instance's name
  config const lb: string   = "lb1";  // lb1, lb1_d, lb2
  config const br: string   = "fwd";  // fwd, bwd, alt, maxSum, minMin, minBranch
  config const ub: string   = "opt";  // opt, inf

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

    // Search
    select mode {
      when "sequential" {
        if activeSet then warning("`activeSet` is ignored in sequential mode");
        search_sequential(Node_PFSP, pfsp, saveTime);
      }
      when "multicore" {
        search_multicore(Node_PFSP, pfsp, saveTime, activeSet);
      }
      when "distributed" {
        search_distributed(Node_PFSP, pfsp, saveTime, activeSet);
      }
      otherwise {
        halt("unknown execution mode");
      }
    }

    return 0;
  }
}
