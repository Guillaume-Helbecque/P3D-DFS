module aux
{
  use Time;
  use CTypes;
  use fsp_node;
  use IO;

  use fsp_aux;
  use uts_aux;

  // Runtime constant: are the leaves printed ?
  config const display: bool = false;

  // Convert a Chapel tuple to a C array
  proc tupleToCptr(t: JOBS*int): c_ptr(c_int)
  {
    var p: c_ptr(c_int) = c_malloc(c_int, JOBS);
    for i in 0..#JOBS do p[i] = t[i]:c_int;
    return p;
  }

  // Print a leaf
  /* proc printLeaf(n: Node): void
  {
    if display then writeln(n.depth, " -- ", JOBS, ", ", n.prmu);
  } */

  // Take a boolean array and return false if it contains at least one "true", "true" if not
  inline proc all_true(const arr: [] atomic bool): bool
  {
    for elt in arr {
      if (elt.read() == false) then return false;
    }

    return true;
  }

  /*
    REMARK: This function is supposed to be called only when the flag is 'false',
    so there is no need to set it when the check is 'false'.
  */
  proc check_and_set(const arr: [] atomic bool, flag: atomic bool): bool
  {
    // if all threads are empty...
    if all_true(arr) {
      // set the flag
      flag.write(true);
      return true;
    }
    else {
      return false;
    }
  }

  proc check_and_set_b(const arr: [] atomic bool, ref flag: bool): bool
  {
    // if all threads are empty...
    if all_true(arr) {
      flag = true;
    }
    else {
      flag = false;
    }
    return flag;
  }

  proc allThreadsEmpty(const arr: [] atomic bool, flag: atomic bool): bool
  {
    // fast exit
    if flag.read() {
      return true;
    }
    else {
      return check_and_set(arr, flag);
    }
  }

  proc allLocalesEmpty(const arr: [] atomic bool, ref flag: atomic bool, cTerm: atomic int): bool
  {
    // fast exit
    if flag.read() {
      return true;
    }
    else {
      cTerm.add(1);
      return check_and_set(arr, flag);
    }
  }

  proc save_subtimes(const path: string, const table: [] real): void
  {
    try! {
      var f: file = open(path, iomode.cw);
      var channel = f.writer();
      channel.write(table);
      channel.close();
      f.close();
    }
  }

  proc helpMessage(): void
  {
    writeln("\n    usage:  main.o [parameter value] ...");
    writeln("\n  General Parameters:\n");
    writeln("   --problem             str   benchmark to be used (fsp, uts)");
    writeln("   --mode                str   parallel execution mode (multi, single)");
    writeln("   --printExploredTree   bool  print explored sub-trees");
    writeln("   --printExploredSol    bool  print explored solutions");
    writeln("   --printMakespan       bool  print optimal makespan");
    writeln("   --dbgProfiler         bool  debugging profiler");
    writeln("   --dbgDiagnostics      bool  debugging diagnostics");
    writeln("   --activeSet           bool  compute and distribute an initial set of elements");
    writeln("   --saveTime            bool  save computational time in a file");
    writeln("   --help (or -h)              this message");
    fsp_helpMessage();
    uts_helpMessage();
  }
}
