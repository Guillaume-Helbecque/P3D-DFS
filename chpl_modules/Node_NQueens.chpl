module Node_NQueens
{
	// Maximum size of the problem
  config param NMax: int = 25;

  record Node_NQueens
  {
    var board: NMax * int;
		var depth: int;

		proc init(){}

		// copy-initializer
		proc init(other: Node_NQueens)
    {
      this.board = other.board;
			this.depth = other.depth;
    }
  };

}
