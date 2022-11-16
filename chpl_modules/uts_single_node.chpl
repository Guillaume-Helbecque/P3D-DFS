module uts_single_node
{
  use List;
  use Time;
  use CTypes;
  use VisualDebug;
  use CommDiagnostics;
  use DistributedBag_DFS;

  use aux;
  use uts_aux;
  use uts_chpl_c_headers;

  config const t: c_int     = -1;
  config const b: c_double  = -1.0;
  config const r: c_int     = -1;
  config const a: c_int     = -1;
  config const d: c_int     = -1;
  config const q: c_double  = -1.0;
  config const m: c_int     = -1;
  config const f: c_double  = -1.0;
  config const g: c_int     = -1;

  proc parseParams(t: c_int, b: c_double, r: c_int, a: c_int, d: c_int, q: c_double,
    m: c_int, f: c_double, g: c_int): void
  {
    if (t != -1)    then treeType = castTo_tree_t(t);
    if (b != -1.0)  then b_0 = b;
    if (r != -1)    then rootId = r;
    if (a != -1)    then shape_fn = castTo_geoshape_t(a);
    if (d != -1)    then gen_mx = d;
    if (q != -1.0)  then nonLeafProb = q;
    if (m != -1)    then nonLeafBF = m;
    if (f != -1.0)  then shiftDepth = f;
    if (g != -1)    then computeGranularity = g;
  }

  proc uts_single_node(const dbgProfiler: bool, const dbgDiagnostics: bool, const saveTime: bool): void
  {
    // Counters and timers (for analysis)
    var ExploredTree: int = 0;
    var ExploredLeaf: int = 0;
    var MaxDepth: int = 0;
    var counter_termination: atomic int = 0;
    var timers: [0..#here.maxTaskPar, 0..3] real;
    var globalTimer: Timer;

    // Debugging options
    if dbgProfiler {
      startVdebug("test");
      tagVdebug("init");
      writeln("Starting profiler");
    }

    if dbgDiagnostics {
      writeln("\n### Starting communication counter ###");
      startCommDiagnostics();
    }

    parseParams(t, b, r, a, d, q, m, f, g);
    print_settings();

    // ===============
    // INITIALIZATION
    // ===============

    var bag = new DistBag_DFS(Node, targetLocales = Locales);
    var root: Node;
    uts_initRoot(root, 0:c_int); // BIN

    bag.add(root, 0);
    ExploredTree += 1;

    writeln("\nInitial state of the bag (locale x task):");
    for loc in Locales do on loc {
      writeln(bag.bag!.segments.nElems);
    }
    writeln("");

    globalTimer.start();

    // =====================
    // PARALLEL EXPLORATION
    // =====================

    // Local variables (termination)
    var allTasksEmptyFlag: atomic bool = false;
    var TaskTermination: [0..#here.maxTaskPar] atomic bool = false;

    // Counters and timers (for analysis)
    var LocalExploredTree: [0..#here.maxTaskPar] int = 0;
    var LocalExploredLeaf: [0..#here.maxTaskPar] int = 0;
    var LocalMaxDepth: [0..#here.maxTaskPar] int = 0;

    coforall tid in 0..#here.maxTaskPar {

      // Counters and timers (for analysis)
      var terminationTimer, decomposeTimer, readTimer, removeTimer: Timer;

      while true do {

        // Try to remove an element
        removeTimer.start();
        var (hasWork, parent): (int, Node) = bag.remove(tid);
        removeTimer.stop();

        /*
          Check (or not) the termination condition regarding the value of 'hasWork':
            'hasWork' = -1 : remove() fails              -> check termination
            'hasWork' =  0 : remove() prematurely fails  -> continue
            'hasWork' =  1 : remove() succeeds           -> decompose
        */

        terminationTimer.start();
        if (hasWork != 1) then TaskTermination[tid].write(true);
        else {
          TaskTermination[tid].write(false);
        }

        if (hasWork == -1) {
          if allTasksEmpty(TaskTermination, allTasksEmptyFlag) { // local check
            terminationTimer.stop();
            break;
          }
        terminationTimer.stop();
        continue;
        }
        else if (hasWork == 0) {
          terminationTimer.stop();
          continue;
        }
        terminationTimer.stop();

        // Decompose an element
        decomposeTimer.start();
        {
          var numChildren: c_int = uts_numChildren(parent);
          var children = c_malloc(Node, numChildren);

          decompose(parent, children, computeGranularity, LocalExploredTree[tid], LocalExploredLeaf[tid], LocalMaxDepth[tid]);

          for i in 0..#numChildren {
            bag.add(children[i], tid);
          }

          c_free(children);
        }
        decomposeTimer.stop();

      }

      timers[tid, 0] = tid;
      timers[tid, 1] = removeTimer.elapsed(TimeUnits.seconds);
      timers[tid, 2] = decomposeTimer.elapsed(TimeUnits.seconds);
      timers[tid, 3] = terminationTimer.elapsed(TimeUnits.seconds);

    } // end coforall tasks

    ExploredTree += (+ reduce LocalExploredTree);
    ExploredLeaf += (+ reduce LocalExploredLeaf);
    MaxDepth = (max reduce LocalMaxDepth);

    globalTimer.stop();
    //bag.clear();

    // ========
    // OUTPUTS
    // ========

    writeln("\nExploration terminated.");

    if saveTime {
      var tup = ("./uts_chpl_", ExploredTree:string, "_", computeGranularity:string, ".txt");
      var path = "".join(tup);
      save_time(here.maxTaskPar:c_int, globalTimer.elapsed(TimeUnits.seconds):c_double, path.c_str());
    }

    if saveTime {
      var tup = ("./uts_chpl_", ExploredTree:string, "_", computeGranularity:string, "_",
        here.maxTaskPar:string,"t_subtimes.txt");
      var path = "".join(tup);
      save_subtimes(path, timers);
    }

    // Debugging options
    if dbgProfiler {
      stopVdebug();
      writeln("### Debuging is done ###");
    }

    if dbgDiagnostics {
      writeln("### Stopping communication counter ###");
      stopCommDiagnostics();
      writeln("\n ### Communication results ### \n", getCommDiagnostics());
    }

    /* writeln("\nNumber of global termination detection: ", counter_termination.read()); */
    print_results(LocalExploredTree, LocalExploredLeaf, globalTimer, LocalMaxDepth);
  }

}
