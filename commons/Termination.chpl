module Termination
{
  /*****************************************************************************
  Known issues:
    - this module is specific to the DistBag_DFS data structure ('hasWork')
    - I need to find a way to return a loop statement ('break' or 'continue')
    - create a debugging mode with statistics
  *****************************************************************************/

  use PrivateDist;

  const BUSY: bool = false;
  const IDLE: bool = true;

  const BREAK: string    = "b";
  const CONTINUE: string = "c";
  const NOTHING: string  = "n";

  record R {
    var r: [0..#here.maxTaskPar] bool;
  }

  class Termination
  {
    const PrivateSpace: domain(1) dmapped Private();

    var taskState: [0..#here.maxTaskPar] bool = false;
    var eachTaskState: [0..#here.maxTaskPar] atomic bool;
    var allTasksIdleFlag: atomic bool = false;

    var locState: [PrivateSpace] R;
    var eachLocaleState: [PrivateSpace] atomic bool;
    var allLocalesIdleFlag: atomic bool = false;

    proc init()
    {
    }

    proc local_task_check(const status: bool, const tid: int)
    {
      if (this.taskState[tid] != status) {
        this.taskState[tid] = status;
        this.eachTaskState[tid].write(status);
      }
    }

    proc local_loc_check(const status: bool, const tid: int, const locId: int)
    {
      if (this.locState[here.id].r[tid] != status) {
        this.locState[here.id].r[tid] = status;
        this.eachLocaleState[here.id].write(status);
      }
    }

    proc check_end_MC(const hasWork: int, const tid: int)
    {
      if (hasWork == 1) {
        local_task_check(BUSY, tid);
      }
      else if (hasWork == 0) {
        local_task_check(IDLE, tid);
        return CONTINUE;
      }
      else {
        local_task_check(IDLE, tid);
        if allIdle(this.eachTaskState, this.allTasksIdleFlag) {
          return BREAK;
        }
        return CONTINUE;
      }
      return NOTHING;
    }

    proc check_end_D(const hasWork: int, const tid: int, const locId: int)
    {
      if (hasWork == 1) {
        local_task_check(BUSY, tid);
        local_loc_check(BUSY, tid, locId);
      }
      else if (hasWork == 0) {
        local_task_check(IDLE, tid);
        return CONTINUE;
      }
      else {
        local_task_check(IDLE, tid);
        if allIdle(this.eachTaskState, this.allTasksIdleFlag) {
          local_loc_check(IDLE, tid, locId);
          if allIdle(this.eachLocaleState, this.allLocalesIdleFlag) {
            return BREAK;
          }
        } else {
          local_loc_check(BUSY, tid, locId);
        }
        return CONTINUE;
      }
      return NOTHING;
    }
  } // end class

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

  proc allLocalesIdle_dbg(const arr: [] atomic bool, flag: atomic bool, cTerm: atomic int): bool
  {
    if flag.read() {
      return true;
    }
    else {
      cTerm.add(1);
      return check_and_set(arr, flag);
    }
  }
}
