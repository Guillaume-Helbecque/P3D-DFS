module Problem
{
  use List;
  use Time;

  class Problem
  {
    proc copy(): Problem
    {
      halt("Error - copy() not implemented");
      return new Problem();
    }

    proc decompose(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int, best: atomic int,
      ref best_task: int): list
    {
      halt("Error - decompose() not implemented");
      var l: list(Node);
      return l;
    }

    // for debugging
    proc print_thing(): void
    {
      halt("Error - print_thing() not implemented");
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
      const subDepthReached: [] int, const best: int, const timer: Timer): void
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
