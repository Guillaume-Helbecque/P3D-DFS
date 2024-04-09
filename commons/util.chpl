module util
{
  use IO;

  param BUSY: bool = false;
  param IDLE: bool = true;

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

  proc allIdle(const arr: [] atomic bool, flag: atomic bool): bool
  {
    if flag.read() {
      return true;
    }
    else {
      return check_and_set(arr, flag);
    }
  }

  proc save_time(const numTasks: int, const time: real, const path: string): void
  {
    try! {
      var f: file = open(path, ioMode.a);
      var channel = f.writer(locking=false);
      channel.writeln(numTasks, " ", time);
      channel.close();
      f.close();
    }
  }

  proc common_help_message(): void
  {
    writeln("\n    usage:  main.o [parameter value] ...");
    writeln("\n  General Parameters:\n");
    writeln("   --mode                str   parallel execution mode (sequential, multicore, distributed)");
    writeln("   --activeSet           bool  compute and distribute an initial set of elements");
    writeln("   --saveTime            bool  save processing time in a file");
    writeln("   --help (or -h)              this message");
  }
}
