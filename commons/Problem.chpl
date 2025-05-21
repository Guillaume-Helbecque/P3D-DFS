module Problem
{
  class Problem
  {
    /* Problem objective: "min", "max", or "none" */
    var obj: string;

    proc copy()
    {
      halt("Error - copy() not implemented");
    }

    proc decompose(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, ref bestCost: int, ref bestBound: int, lock: sync bool,
      ref bestCost_task: int)
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
      const subDepthReached, const bestCost: int, const bestBound: int,
      const elapsedTime: real): void
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
