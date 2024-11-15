module main_pfsp
{
  use launcher;

  // PFSP-specific modules
  use Node_PFSP;
  use Problem_PFSP;

  // PFSP-specific options
  config const inst: string = "ta14"; // instance's name
  config const lb: string   = "lb1";  // lb1, lb1_d, lb2
  config const br: string   = "fwd";  // fwd, bwd, alt, maxSum, minMin, minBranch
  config const ub: string   = "opt";  // opt, inf

  proc main(args: [] string): int
  {
    // Initialization of the problem
    var pfsp = new Problem_PFSP(inst, lb, br, ub);
    var root = new Node_PFSP(pfsp);
    launcher(args, root, pfsp);

    return 0;
  }
}
