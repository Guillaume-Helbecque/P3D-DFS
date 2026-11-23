module main_uts
{
  use commons;

  // Problem-specific modules
  use Node_UTS;
  use Problem_UTS;

  // Problem-specific options
  use CTypes;
  config const t: c_int    = 0; // BIN
  config const b: c_double = 2000.0;
  config const r: c_int    = 30;
  config const a: c_int    = 0; // LINEAR
  config const d: c_int    = 6;
  config const q: c_double = 0.499995;
  config const m: c_int    = 2;
  config const f: c_double = 0.5;
  config const g: c_int    = 1;

  proc main(args: [] string): int
  {
    // initialize problem instance
    var uts = new Problem_UTS(t, b, r, m, q, d, a, f, g);
    // initialize root node
    var root = new Node_UTS(t, r);

    // launch B&B search
    run_search(args, root, uts);

    return 0;
  }
}
