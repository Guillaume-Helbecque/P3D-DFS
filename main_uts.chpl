module main_uts
{
  // Common modules
  use CTypes;

  use util;
  use search_sequential;
  use search_multicore;
  use search_distributed;

  // UTS-specific modules
  use Node_UTS;
  use Problem_UTS;

  // Common options
  config const mode: string    = "multicore"; // sequential, multicore, distributed
  config const activeSet: bool = false;
  config const saveTime: bool  = false;

  // UTS-specific options
  config const t: c_int    = 0; // BIN
  config const b: c_double = 2000.0;
  config const r: c_int    = 0;
  config const a: c_int    = 0; // LINEAR
  config const d: c_int    = 6;
  config const q: c_double = 0.499995;
  config const m: c_int    = 2;
  config const f: c_double = 0.5;
  config const g: c_int    = 1;

  proc main(args: [] string): int
  {
    // Initialization of the problem
    var uts = new Problem_UTS(t, b, r, m, q, d, a, f, g);

    // Helper
    for a in args[1..] {
      if (a == "-h" || a == "--help") {
        common_help_message();
        uts.help_message();

        return 1;
      }
    }

    // Search
    select mode {
      when "sequential" {
        if activeSet then warning("Cannot use `activeSet` in sequential mode.");
        search_sequential(Node_UTS, uts, saveTime);
      }
      when "multicore" {
        search_multicore(Node_UTS, uts, saveTime, activeSet);
      }
      when "distributed" {
        search_distributed(Node_UTS, uts, saveTime, activeSet);
      }
      otherwise {
        halt("ERROR - Unknown execution mode");
      }
    }

    return 0;
  }
}
