module Problem
{
  use Time;

  class Problem
  {
    proc copy()
    {
      halt("Error - copy() not implemented");
    }

    proc decompose(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int, best: atomic int,
      ref best_task: int)
    {
      halt("Error - decompose() not implemented");
    }

    proc setInitUB(): int
    {
      halt("Error - setInitUB() not implemented");
    }

    // =======================
    // Utility functions
    // =======================

    proc print_settings(): void
    {
      halt("Error - print_settings() not implemented");
    }

    proc print_results(const subNodeExplored: [] int, const subSolExplored: [] int,
      const subDepthReached: [] int, const best: int, const timer: stopwatch): void
    {
      halt("Error - print_results() not implemented");
    }

    proc output_filepath(): string
    {
      halt("Error - output_filepath() not implemented");
    }

    proc help_message(): void
    {
      halt("Error - help_message() not implemented");
    }
  } // end class

} // end module
