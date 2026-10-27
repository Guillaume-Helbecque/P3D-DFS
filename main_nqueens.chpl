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
    // initialize problem instance
    var nqueens = new Problem_NQueens(N);
    // initialize root node
    var root = new Node_NQueens(N);

    // launch B&B search
    run_search(args, root, nqueens);

    return 0;
  }
}
