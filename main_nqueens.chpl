module main_queens
{
  use commons;

  // Problem-specific modules
  use Node_NQueens;
  use Problem_NQueens;

  // Problem-specific option
  config const N: int = 13;

  proc main(args: [] string): int
  {
    // Initialization of the problem
    var nqueens = new Problem_NQueens(N);

    run_search(args, Node_NQueens, nqueens);

    return 0;
  }
}
