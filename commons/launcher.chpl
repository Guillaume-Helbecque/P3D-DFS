module launcher
{
  // Common modules
  use search_sequential;
  use search_multicore;
  use search_distributed;

  use Problem;

  // Common options
  config const mode: string    = "multicore"; // sequential, multicore, distributed
  config const activeSet: bool = false;
  config const saveTime: bool  = false;

  private proc common_help_message(): void
  {
    writeln("\n    usage:  main.o [parameter value] ...");
    writeln("\n  General Parameters:\n");
    writeln("   --mode                str   parallel execution mode (sequential, multicore, distributed)");
    writeln("   --activeSet           bool  compute and distribute an initial set of elements");
    writeln("   --saveTime            bool  save processing time in a file");
    writeln("   --help (or -h)              this message");
  }

  proc launcher(args: [] string, root, problem): int
  {
    // Helper
    for a in args[1..] {
      if (a == "-h" || a == "--help") {
        common_help_message();
        problem.help_message();

        return 1;
      }
    }

    // Search
    select mode {
      when "sequential" {
        if activeSet then warning("Cannot use `activeSet` in sequential mode.");
        search_sequential(root, problem, saveTime);
      }
      when "multicore" {
        search_multicore(root, problem, saveTime, activeSet);
      }
      when "distributed" {
        search_distributed(root, problem, saveTime, activeSet);
      }
      otherwise {
        halt("ERROR - Unknown execution mode");
      }
    }

    return 0;
  }
}
