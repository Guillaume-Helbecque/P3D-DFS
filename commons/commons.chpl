module commons
{
  // Common modules
  use search_sequential;
  use search_multicore;
  use search_distributed;

  // Common options
  config const mode: string    = "multicore"; // sequential, multicore, distributed
  config const findAll: bool   = false;
  config const activeSet: bool = false;
  config const saveTime: bool  = false;

  proc common_help_message(executable): void
  {
    writeln("\n    usage:   ", executable, " [parameter value] ...");
    writeln("\n  General Parameters:\n");
    writeln("   --mode           str    parallel execution mode (sequential, multicore, distributed)");
    writeln("   --findAll        bool   find all optimal solutions");
    writeln("   --activeSet      bool   compute and distribute an initial set of elements");
    writeln("   --saveTime       bool   save processing time in a file");
    writeln("   --help (or -h)          print this message");
  }

  proc handle_help(const args : [] string, const ref problem) : void
  {
    for a in args[1..] {
      if (a == "-h" || a == "--help") {
        common_help_message(args[0]);
        problem.help_message();

        exit(1);
      }
    }
  }

  proc run_search(const args : [] string, type NodeType, const ref problem) : void
  {
    // Help
    handle_help(args, problem);

    // Search
    select mode {
      when "sequential" {
        if activeSet then warning("`activeSet` is ignored in sequential mode");
        search_sequential(NodeType, problem, saveTime);
      }
      when "multicore" {
        search_multicore(NodeType, problem, saveTime, activeSet);
      }
      when "distributed" {
        search_distributed(NodeType, problem, saveTime, activeSet);
      }
      otherwise {
        halt("unknown execution mode");
      }
    }
  }
}
