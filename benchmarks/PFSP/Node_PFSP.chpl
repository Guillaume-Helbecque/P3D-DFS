module Node_PFSP
{
  use CTypes;

  // Maximum number of jobs in PFSP Taillard's instances.
  config param JobsMax: int = 50;

  record Node_PFSP
  {
    var depth: int;
    var limit1: int; // right limit
    var limit2: int; // left limit
    var prmu: c_array(c_int, JobsMax);
    var lb: real;

    // default-initializer
    proc init()
    {}

    // root-initializer
    proc init(problem)
    {
      this.limit1 = -1;
      this.limit2 = problem.jobs;
      init this;
      for i in 0..#problem.jobs do this.prmu[i] = i:c_int;
      this.lb = 1e-6;
    }

    // copy-initializer
    proc init(other: Node_PFSP)
    {
      this.depth  = other.depth;
      this.limit1 = other.limit1;
      this.limit2 = other.limit2;
      this.prmu   = other.prmu;
      this.lb     = other.lb;
    }

    proc deinit()
    {}
  }
}
