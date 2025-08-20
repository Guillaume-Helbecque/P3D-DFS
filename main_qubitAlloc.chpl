module main_qubitAlloc
{
  // Common modules
  use util;
  use search_sequential;
  use search_multicore;
  use search_distributed;

  // Problem-specific modules
  use Node_QubitAlloc;
  use Problem_QubitAlloc;

  // Common options
  config const mode: string    = "multicore"; // sequential, multicore, distributed
  config const activeSet: bool = false;
  config const saveTime: bool  = false;

  // Problem-specific option
  // TODO: add, if any
  config const inter = "10_sqn";
  config const dist = "16_melbourne";
  config const itmax: int(32) = 10;

  proc main(args: [] string): int
  {
    // Initialization of the problem
    var qubitAlloc = new Problem_QubitAlloc(inter, dist, itmax);

    // Helper
    for a in args[1..] {
      if (a == "-h" || a == "--help") {
        common_help_message();
        qubitAlloc.help_message();

        return 1;
      }
    }

    // Search
    select mode {
      when "sequential" {
        if activeSet then warning("`activeSet` is ignored in sequential mode");
        search_sequential(Node_QubitAlloc, qubitAlloc, saveTime);
      }
      when "multicore" {
        search_multicore(Node_QubitAlloc, qubitAlloc, saveTime, activeSet);
      }
      /* when "distributed" {
        search_distributed(Node_QubitAlloc, qubitAlloc, saveTime, activeSet);
      } */
      otherwise {
        halt("unknown execution mode");
      }
    }

    return 0;
  }
}
