module Node_PFSP
{
  // Compilation constant: size of the problem
  config param JOBS: int = 20;

  // Node record
  record Node_PFSP
  {
    // var size: int;       // size of the problem (= JOBS, can be removed ?)
    var depth: int;         // depth
    var limit1: int;        // right limit
    var limit2: int;        // left limit
    var prmu: (JOBS*int);   // permutation

    // default initializer
    proc init()
    {
      // this.size = JOBS;
      this.depth  = 0;
      this.limit1 = -1;
      this.limit2 = JOBS;
      var tmp: JOBS*int;
      for i in 0..#JOBS do tmp(i) = i;
      this.prmu = tmp;
    }

    // copy initializer
    proc init(from: Node_PFSP)
    {
      // this.size = from.size;
      this.depth  = from.depth;
      this.limit1 = from.limit1;
      this.limit2 = from.limit2;
      this.prmu   = from.prmu;
    }
  }
}
