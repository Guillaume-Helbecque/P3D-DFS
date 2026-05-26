module Node_QAP
{
  use CTypes;

  config param sizeMax: int(32) = 27;
  param sizeMaxSq: int(32) = sizeMax * sizeMax;

  record Node_QAP
  {
    var mapping: c_array(c_int, sizeMax);
    var lower_bound: int;
    var depth: uint(8);
    var available: c_array(c_int, sizeMax);

    /*
      QPB-specific data (zero-init at default; populated by the QPB wrapper
      when the child subproblem is square).
    */
    var qpb_has_data: c_int;             // 1 when the buffers below are valid
    var qpb_m: c_int;                    // child subproblem size (n - depth)
    var qpb_fixed_cost: int(64);         // child's assigned-pairs fixed cost
    var qpb_bound_cont: real(64);        // continuous QPB bound (best across FW iters, with asym correction)
    var qpb_bound_cont_last: real(64);   // continuous QPB bound from the last FW iter (drives variable fixing)
    var qpb_X: c_array(real(64), sizeMaxSq);             // primal doubly-stochastic, column-major m*m
    var qpb_reduced_costs: c_array(real(64), sizeMaxSq); // dual reduced costs, column-major m*m
    var qpb_unassigned_fac: c_array(c_int, sizeMax);     // unassigned facility indices (m of them)
    var qpb_unassigned_loc: c_array(c_int, sizeMax);     // unassigned location indices (m of them)

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
      this.mapping     = other.mapping;
      this.lower_bound = other.lower_bound;
      this.depth       = other.depth;
      this.available   = other.available;
    }
  }
}
