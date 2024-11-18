module Problem
{
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

    proc print_settings(): void {}

    proc print_results(const subNodeExplored: [] int, const subSolExplored: [] int,
      const subDepthReached: [] int, const best: int, const elapsedTime: real): void {}

    proc output_filepath(): string {
      return "";
    }

    proc help_message(): void {}
  } // end class

} // end module
