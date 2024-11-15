module Node_NQueens
{
  /*
    Maximum size of the problem. The exact number of N-Queens solutions is only
    known for N < 28.
  */
  config param NMax: int = 27;

  record Node_NQueens
  {
    var board: NMax*uint(8);
    var depth: uint(8);

    // default-initializer
    proc init()
    {}

    // root-initializer
    proc init(const N: int)
    {
      init this;
      for i in 0..#N do this.board[i] = i:uint(8);
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
