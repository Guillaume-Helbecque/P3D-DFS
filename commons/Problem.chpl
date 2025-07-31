module Problem
{
  class Problem
  {
    proc copy()
    {
      compilerError("Problem.copy() not implemented");
    }

    proc decompose(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, ref best: int, lock: sync bool, ref best_task: int)
    {
      compilerError("Problem.decompose() not implemented");
    }

    proc getInitBound(): int
    {
      compilerError("Problem.getInitBound() not implemented");
    }

    // =======================
    // Utility functions
    // =======================

    proc print_settings(): void
    {
      compilerWarning("Problem.print_settings() not implemented");
    }

    proc print_results(const subNodeExplored, const subSolExplored,
      const subDepthReached, const best: int, const elapsedTime: real): void
    {
      compilerWarning("Problem.print_results() not implemented");
    }

    proc output_filepath(): string
    {
      compilerWarning("Problem.output_filepath() not implemented");
      return "";
    }

    proc help_message(): void
    {
      compilerWarning("Problem.help_message() not implemented");
    }
  } // end class

} // end module
