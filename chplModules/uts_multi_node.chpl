module uts_multi_node
{
  use List;
  use Time;
  use CTypes;
  use PrivateDist;
  use VisualDebug;
  use CommDiagnostics;
  use DistributedBag_one_block_locked;
  use AllLocalesBarriers;

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
    coforall loc in Locales do on loc {
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
  }

  proc uts_multi_node(const dbgProfiler: bool, const dbgDiagnostics: bool): void
  {
    // Global variables (termination)
    const PrivateSpace: domain(1) dmapped Private(); // map each index to a locale
    var eachLocaleTermination: [PrivateSpace] atomic bool = false;
    allLocalesBarrier.reset(here.maxTaskPar); // configuration of the global barrier

    // Counters and timers (for analysis)
    var eachExploredTree: [PrivateSpace] int = 0;
    var eachExploredLeaf: [PrivateSpace] int = 0;
    var eachMaxDepth: [PrivateSpace] int = 0;
    var counter_termination: atomic int = 0;
    var timers: [0..#numLocales, 0..#here.maxTaskPar, 0..4] real;
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

    var bag = new DistBag(Node, targetLocales = Locales);
    var root: Node;
    uts_initRoot(root, 0:c_int); // BIN

    bag.add(root, 0);
    eachExploredTree[0] += 1;

    writeln("\nInitial state of the bag (locale x thread):");
    for loc in Locales do on loc {
      writeln(bag.bag!.segments.nElems);
    }
    writeln("");

    globalTimer.start();

    // =====================
    // PARALLEL EXPLORATION
    // =====================

    coforall loc in Locales do on loc {

      // Local variables (termination)
      var allThreadsEmptyFlag: atomic bool = false;
      var globalTerminationFlag: atomic bool = false;
      var eachThreadTermination: [0..#here.maxTaskPar] atomic bool = false;

      // Counters and timers (for analysis)
      var eachLocalExploredTree: [0..#here.maxTaskPar] int = 0;
      var eachLocalExploredLeaf: [0..#here.maxTaskPar] int = 0;
      var eachLocalMaxDepth: [0..#here.maxTaskPar] int = 0;

      coforall tid in 0..#here.maxTaskPar {

        // Counters and timers (for analysis)
        var terminationTimer, decomposeTimer, readTimer, removeTimer: Timer;

        allLocalesBarrier.barrier(); // synchronization of threads

        while true do {

          // Try to remove an element
          removeTimer.start();
          var (hasWork, parent): (bool, Node) = bag.remove(tid);
          removeTimer.stop();

          /*
            Check (or not) the termination condition regarding the value of 'hasWork':
              'hasWork' = -1 : remove() fails              -> check termination
              'hasWork' =  0 : remove() prematurely fails  -> continue
              'hasWork' =  1 : remove() succeeds           -> decompose
          */

          terminationTimer.start();
          if (hasWork != true) then eachThreadTermination[tid].write(true);
          else {
            eachThreadTermination[tid].write(false);
            eachLocaleTermination[here.id].write(false);
          }

          if (hasWork == false) {
            if allThreadsEmpty(eachThreadTermination, allThreadsEmptyFlag) { // local check
              eachLocaleTermination[here.id].write(true);

                if allLocalesEmpty(eachLocaleTermination, globalTerminationFlag, counter_termination) { // global check
                  terminationTimer.stop();
                  break;
                }

            } else {
              eachLocaleTermination[here.id].write(false);
            }
          terminationTimer.stop();
          continue;
          }
          /* else if (hasWork == 0) {
            terminationTimer.stop();
            continue;
          } */
          terminationTimer.stop();

          // Decompose an element
          decomposeTimer.start();
          {
            var numChildren: c_int = uts_numChildren(parent);
            var children = c_malloc(Node, numChildren);

            decompose(parent, children, computeGranularity, eachLocalExploredTree[tid], eachLocalExploredLeaf[tid], eachLocalMaxDepth[tid]);

            for i in 0..#numChildren {
              bag.add(children[i], tid);
            }

            c_free(children);
          }
          decomposeTimer.stop();

        }

        timers[loc.id, tid, 0] = loc.id;
        timers[loc.id, tid, 1] = tid;
        timers[loc.id, tid, 3] = decomposeTimer.elapsed(TimeUnits.seconds);
        timers[loc.id, tid, 4] = terminationTimer.elapsed(TimeUnits.seconds);
        timers[loc.id, tid, 2] = removeTimer.elapsed(TimeUnits.seconds);
      } // end coforall threads

      eachExploredTree[here.id] += (+ reduce eachLocalExploredTree);
      eachExploredLeaf[here.id] += (+ reduce eachLocalExploredLeaf);
      eachMaxDepth[here.id] = (max reduce eachLocalMaxDepth);

    } // end coforall locales

    globalTimer.stop();
    //bag.clear();

    // ========
    // OUTPUTS
    // ========

    writeln("\nExploration terminated.");

    /* if saveTime { */
      var tup = ("./uts_chpl_", (+ reduce eachExploredTree):string, "_", computeGranularity:string, "_dist_locked.txt");
      var path = "".join(tup);
      save_time(here.maxTaskPar:c_int, globalTimer.elapsed(TimeUnits.seconds):c_double, path.c_str());
    /* } */

    {
      var tup = ("./uts_chpl_", (+ reduce eachExploredTree):string, "_", computeGranularity:string, "_",
        numLocales:string,"n_subtimes_locked.txt");
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

    /* for loc in Locales do on loc {
      writeln("\nON ", loc, " :");
      writeln("Intra-node nSteal ", bag.bag!.segments.nSteal1);
      writeln("Intra-node nSSteal on ", bag.bag!.segments.nSSteal1);
      writeln("Intra-node timer on ", bag.bag!.segments.timer1.elapsed(TimeUnits.seconds));
      writeln("");
      writeln("Inter-node nSteal on ", bag.bag!.segments.nSteal2);
      writeln("Inter-node nSSteal on ", bag.bag!.segments.nSSteal2);
      writeln("Inter-node timer on ", bag.bag!.segments.timer2.elapsed(TimeUnits.seconds));
    } */

    writeln("\nNumber of global termination detection: ", counter_termination.read());
    print_results(eachExploredTree, eachExploredLeaf, globalTimer, eachMaxDepth);
  }

}
