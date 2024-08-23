module Node_NQueens
{
  /*
    Maximum size of the problem. The exact number of N-Queens solutions is only
    known for N < 28.
  */
  config param NMax: int = 27;

  record Node_NQueens
  {
    var board: NMax*int(32);
    var depth: int;

    // default-initializer
    proc init()
    {}

    // root-initializer
    proc init(problem)
    {
      init this;
      for i in 0..#problem.N do this.board[i] = i:int(32);
    }

    // copy-initializer
    proc init(other: Node_NQueens)
    {
      this.board = other.board;
      this.depth = other.depth;
    }

    proc deinit()
    {}
  }

}
