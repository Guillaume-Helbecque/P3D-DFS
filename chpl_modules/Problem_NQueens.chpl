module Problem_NQueens
{
  use List;
  use Time;

  use Problem;
  use Node_NQueens;

  class NQueens : Problem {
    // Size of the problem (number of queens)
    var N: int;

    proc init(const n: int): void
    {
      this.N = n;
    }

    override proc copy(): Problem
    {
      return new NQueens(N);
    }

    proc isSafe(const board, const queen_num: int, const row_pos: int): bool
    {
      // For each queen before this one
      for i in 0..#queen_num {
        // Get the row position
        const other_row_pos: int = board[i];

        // Check if it is in the same row or diagonals
        if (other_row_pos == row_pos ||                 // Same row
          other_row_pos == row_pos - (queen_num - i) || // Same diagonal
          other_row_pos == row_pos + (queen_num - i))   // Same diagonal
          {
            return false;
          }
        }
      return true;
    }

    override proc decompose(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int, best: atomic int,
      ref best_task: int): list
    {
      var childList: list(Node);

      const firstEmptyRow: int = parent.depth;

      if (firstEmptyRow == N) { // All queens are placed
        num_sol += 1;
      }
      for j in 0..#N {
        if isSafe(parent.board, firstEmptyRow, j) {
          var child = new Node(parent);
          child.board[firstEmptyRow] = j;
          child.depth += 1;
          childList.append(child);
          tree_loc += 1;
        }
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
      writeln("\n=================================================");
      writeln("Resolution of the ", N, "-Queens instance");
      writeln("=================================================");
    }

    override proc print_results(const subNodeExplored: [] int, const subSolExplored: [] int,
      const subDepthReached: [] int, const best: int, const timer: Timer): void
    {
      var treeSize: int = (+ reduce subNodeExplored);
      var nbSol: int = (+ reduce subSolExplored);
      var par_mode: string = if (numLocales == 1) then "tasks" else "locales";

      writeln("\n=================================================");
      writeln("Size of the explored tree: ", treeSize);
      /* writeln("Size of the explored tree per locale: ", sizePerLocale); */
      writeln("% of the explored tree per ", par_mode, ": ", 100 * subNodeExplored:real / treeSize:real);
      writeln("Number of explored solutions: ", nbSol);
      /* writeln("Number of explored solutions per locale: ", numSolPerLocale); */
      writeln("Elapsed time: ", timer.elapsed(TimeUnits.seconds), " [s]");
      writeln("=================================================\n");
    }

    override proc output_filepath(): string
    {
      var tup = ("./chpl_nqueens_", N:string, ".txt");
      return "".join(tup);
    }

    override proc help_message(): void
    {
      writeln("\n  NQueens Benchmark Parameters:\n");
      writeln("   --N   int   Problem size (number of queens)\n");
    }

  } // end class

} // end module
