module Problem
{
  enum ProblemType { Max, Min, Enum }

  class Problem
  {
    proc copy()
    {
      halt("Error - copy() not implemented");
    }

    proc decompose(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, ref best: int, lock: sync bool, ref best_task: int)
    {
      halt("Error - decompose() not implemented");
    }

    proc getInitBound(): int
    {
      halt("Error - getInitBound() not implemented");
    }

    // =======================
    // Utility functions
    // =======================

    proc print_settings(): void
    {
      halt("Error - print_settings() not implemented");
    }

    proc print_results(const subNodeExplored, const subSolExplored,
      const subDepthReached, const best: int, const elapsedTime: real, const bestBound: real = 0): void
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
