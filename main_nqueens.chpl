module main_queens
{
  use launcher;

  // NQueens-specific modules
  use Node_NQueens;
  use Problem_NQueens;

  // NQueens-specific option
  config const N: int = 13;

  proc main(args: [] string): int
  {
    // Initialization of the problem
    const nqueens = new Problem_NQueens(N);
    const root = new Node_NQueens(N);
    launcher(args, root, nqueens);

    return 0;
  }
}
