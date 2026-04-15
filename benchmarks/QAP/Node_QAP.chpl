module Node_QAP
{
  use CTypes;

  use Util;

  config param sizeMax: int(32) = 27;

  record Node_QAP
  {
    var mapping: c_array(c_int, sizeMax);
    var lower_bound: int;
    var depth: uint(8);
    var available: c_array(c_int, sizeMax);

    // default-initializer
    proc init()
    {}

    // root-initializer
    proc init(problem)
    {
      init this;
      for i in 0..<problem.n do this.mapping[i] = -1:c_int;
      for i in 0..<sizeMax do this.available[i] = 1:c_int;
    }

    // copy-initializer
    proc init(other: Node_QAP)
    {
      this.mapping = other.mapping;
      this.lower_bound = other.lower_bound;
      this.depth = other.depth;
      this.available = other.available;
    }
  }
}
