module util
{
  use IO;
  use List;

  param BUSY: bool = false;
  param IDLE: bool = true;

  enum solverStatus { optimal, timelimit, infeasible }
  import Problem.problemType;

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

  proc common_help_message(executable): void
  {
    writeln("\n    usage:   ", executable, " [parameter value] ...");
    writeln("\n  General Parameters:\n");
    writeln("   --mode           str    parallel execution mode (sequential, multicore, distributed)");
    writeln("   --timelimit      real   time limit for B&B solver (in seconds)");
    writeln("   --activeSet      bool   compute and distribute an initial set of elements");
    writeln("   --saveTime       bool   save processing time in a file");
    writeln("   --help (or -h)          print this message");
  }

  proc pushFrontSafe(ref L: list(?), lockList: sync, elt): void
  {
    lockList.readFE(); // acquire
    L.insert(0, elt);
    lockList.writeEF(false); // release
  }

  proc popBackSafe(ref L: list(?), lockList: sync, inout elt): bool
  {
    lockList.readFE();
    if L.size > 0 {
      elt = L.popBack();
      lockList.writeEF(false);
      return true;
    } else {
      lockList.writeEF(false);
      return false;
    }
  }

  proc getBestBound(ref pool, const pbType, parmode = false): real
  {
    // Early exit if not an optimization problem
    if (pbType == problemType.Enum) then return 0.0;

    var bestBound: real;

    if parmode {
      // parallel reduce
      if (pbType == problemType.Max) {
        bestBound = min(real);
        forall elt in pool with (ref bestBound) do bestBound = max(bestBound, elt.bound);
      }
      else {
        bestBound = max(real);
        forall elt in pool with (ref bestBound) do bestBound = min(bestBound, elt.bound);
      }

      /* if (numLocales > 1) {
        // multiple locales
        var eachBestBound: [PrivateSpace] real;
        coforall loc in Locales with (ref eachBestBound) do on loc {
          var eachLocalBestBound: [0..#numTasks] real;
          coforall taskId in 0..#numTasks with (ref eachLocalBestBound) {
            var bestBound_: real;
            while true do {
              var (hasWork, elt) = pool.remove(taskId);
              if (hasWork == 1) {
                if (pbType == problemType.Max) then
                  bestBound_ = max(bestBound_, elt.bound);
                else
                  bestBound_ = min(bestBound_, elt.bound);
              }
              else break;
            }
            eachLocalBestBound[taskId] = bestBound_;
          }

          if (pbType == problemType.Max) then
            eachBestBound[here.id] = (max reduce eachLocalBestBound);
          else
            eachBestBound[here.id] = (min reduce eachLocalBestBound);
        }

        if (pbType == problemType.Max) then
          bestBound = (max reduce eachBestBound);
        else
          bestBound = (min reduce eachBestBound);
      }
      else {
        // single locale
        var eachBestBound: [0..#numTasks] real;
        coforall taskId in 0..#numTasks with (ref eachBestBound) {
          var bestBound_: real;
          while true do {
            var (hasWork, elt) = pool.remove(taskId);
            if (hasWork == 1) {
              if (pbType == problemType.Max) then
                bestBound_ = max(bestBound_, elt.bound);
              else
                bestBound_ = min(bestBound_, elt.bound);
            }
            else break;
          }
          eachBestBound[taskId] = bestBound_;
        }

        if (pbType == problemType.Max) then
          bestBound = (max reduce eachBestBound);
        else
          bestBound = (min reduce eachBestBound);
      } */
    }
    else {
      // sequential reduce
      if (pbType == problemType.Max) {
        bestBound = min(real);
        for elt in pool do bestBound = max(bestBound, elt.bound);
      }
      else {
        bestBound = max(real);
        for elt in pool do bestBound = min(bestBound, elt.bound);
      }
    }

    return bestBound;
  }
}
