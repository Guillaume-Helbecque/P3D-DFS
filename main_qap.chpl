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
    // initialize problem instance
    var qap = new Problem_QAP(inst, itmax, lb, ub);
    // initialize root node
    var root = new Node_QAP(qap);

    // launch B&B search
    run_search(args, root, qap);

    return 0;
  }
}
