module aux
{
  use IO;

  const BUSY: bool = false;

  // Take a boolean array and return false if it contains at least one "true", "true" if not
  inline proc all_idle(const arr: [] atomic bool): bool
  {
    for elt in arr {
      if (elt.read() == BUSY) then return false;
    }

    return true;
  }

  /*
    REMARK: This function is supposed to be called only when the flag is 'false',
    so there is no need to set it when the check is 'false'.
  */
  proc check_and_set(const arr: [] atomic bool, flag: atomic bool): bool
  {
    // if all tasks are empty...
    if all_idle(arr) {
      // set the flag
      flag.write(true);
      return true;
    }
    else {
      return false;
    }
  }

  proc allTasksIdle(const arr: [] atomic bool, flag: atomic bool): bool
  {
    // fast exit
    if flag.read() {
      return true;
    }
    else {
      return check_and_set(arr, flag);
    }
  }

  proc allLocalesIdle(const arr: [] atomic bool, flag: atomic bool): bool
  {
    // fast exit
    if flag.read() {
      return true;
    }
    else {
      return check_and_set(arr, flag);
    }
  }

  proc allLocalesIdle_dbg(const arr: [] atomic bool, flag: atomic bool, cTerm: atomic int): bool
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

  proc common_help_message(): void
  {
    writeln("\n    usage:  main.o [parameter value] ...");
    writeln("\n  General Parameters:\n");
    writeln("   --mode                str   parallel execution mode (multicore, distributed)");
    /* writeln("   --printExploredTree   bool  print explored sub-trees");
    writeln("   --printExploredSol    bool  print explored solutions");
    writeln("   --printMakespan       bool  print optimal makespan"); */
    writeln("   --activeSet           bool  computes and distributes an initial set of elements");
    writeln("   --saveTime            bool  save processing time in a file");
    writeln("   --help (or -h)              this message");
  }
}
