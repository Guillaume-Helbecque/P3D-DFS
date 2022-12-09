module Problem_NQueens
{
  use List;
  use Time;
  use CTypes;

  use Problem;
  use Node_QAP;
  use Header_chpl_c_QAP;

  class QAP : Problem {
    var size: int;

    proc init(const s: int): void
    {
      this.size = s;
    }

    override proc copy(): Problem
    {
      return new QAP(size);
    }

    override proc decompose(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int, best: atomic int,
      ref best_task: int): list
    {
      var childList: list(Node);

      for i in 0..size {

      }

      return childList;
    }

    // No bounding in NQueens
    override proc setInitUB(): int
    {
      return 0;
    }

    proc free(): void
    {

    }

    // =======================
    // Utility functions
    // =======================

    override proc print_settings(): void
    {

    }

    override proc print_results(const subNodeExplored: [] int, const subSolExplored: [] int,
      const subDepthReached: [] int, const best: int, const timer: Timer): void
    {

    }

    // TO COMPLETE
    override proc output_filepath(): string
    {
      var tup = ("./chpl_qap.txt");
      return "".join(tup);
    }

    override proc help_message(): void
    {
      writeln("\n  QAP Benchmark Parameters:\n");
      writeln("   --N   int   Number of queens\n");
    }

  } // end class

} // end module
