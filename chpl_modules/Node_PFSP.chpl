module Node_PFSP
{
  use CTypes;

  // Maximum number of jobs in PFSP Taillard's instances.
  config param JobsMax: int = 500;

  record Node_PFSP
  {
    var depth: int;
    var limit1: int; // right limit
    var limit2: int; // left limit
    var prmu: c_array(c_int, JobsMax);

    // default-initializer
    proc init()
    {}

    // root-initializer
    proc init(problem)
    {
      this.depth  = 0;
      this.limit1 = -1;
      this.limit2 = problem.jobs;
      this.complete();
      for i in 0..#problem.jobs do this.prmu(i) = i:c_int;
    }

    // copy-initializer
    proc init(other: Node_PFSP)
    {
      this.depth  = other.depth;
      this.limit1 = other.limit1;
      this.limit2 = other.limit2;
      this.prmu   = other.prmu;
    }

    proc deinit()
    {}
  }
}
