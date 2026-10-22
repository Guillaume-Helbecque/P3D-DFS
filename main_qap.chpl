module main_qap
{
  use commons;

  // Problem-specific modules
  use Node_QAP;
  use Problem_QAP;

  // Problem-specific option
  config const inst           = "10_sqn,16_melbourne";
  config const itmax: int(32) = 10;
  config const ub: string     = "heuristic"; // heuristic
  config const lb: string     = "glb"; // glb, hhb

  proc main(args: [] string): int
  {
    // Initialization of the problem
    var qap = new Problem_QAP(inst, itmax, lb, ub);

    run_search(args, Node_QAP, qap);

    return 0;
  }
}
