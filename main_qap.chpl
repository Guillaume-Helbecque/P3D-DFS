module main_qap
{
  // Common modules
  use util;
  use search_sequential;
  use search_multicore;
  use search_distributed;

  // Problem-specific modules
  use Node_QAP;
  use Problem_QAP;

  // Common options
  config const mode: string    = "multicore"; // sequential, multicore, distributed
  config const activeSet: bool = false;
  config const saveTime: bool  = false;

  // Problem-specific option
  config const inst           = "10_sqn,16_melbourne";
  config const itmax: int(32) = 10;
  config const ub: string     = "heuristic"; // heuristic
  config param _lb: string    = "glb"; // glb, hhb

  proc main(args: [] string): int
  {
    // Initialization of the problem
    var qap = new Problem_QAP(inst, itmax, ub);

    // Helper
    for a in args[1..] {
      if (a == "-h" || a == "--help") {
        common_help_message(args[0]);
        qap.help_message();

        return 1;
      }
    }

    type Node_QAP = if (_lb == "glb") then Node_QAP_GLB else Node_QAP_HHB;

    // Search
    select mode {
      when "sequential" {
        if activeSet then warning("`activeSet` is ignored in sequential mode");
        search_sequential(Node_QAP, qap, saveTime);
      }
      when "multicore" {
        search_multicore(Node_QAP, qap, saveTime, activeSet);
      }
      when "distributed" {
        search_distributed(Node_QAP, qap, saveTime, activeSet);
      }
      otherwise {
        halt("unknown execution mode");
      }
    }

    return 0;
  }
}
