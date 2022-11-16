module fsp_simple_m_bound_multi_node
{
  use List;
  use Time;
  use CTypes;
  use PrivateDist;
  use VisualDebug;
  use CommDiagnostics;
  use DistributedBag_one_block;
  use AllLocalesBarriers;

  use aux;
  use fsp_aux;
  use fsp_node;
  use statistics;
  use fsp_aux_mlocale;
  use fsp_simple_chpl_c_headers;

  // Decompose a parent node and return the list of its feasible child nodes
  proc decompose(const parent: Node, ref tree_loc: int, ref num_sol: int, const jobs: c_int, const machines: c_int,
    side: int, best: atomic int, ref best_locale: int, ref best_thread: int, const lb1_data: c_ptr(bound_data)): list
  {
    var childList: list(Node); // list containing the child nodes

    // Computation of lowerbounds
    var c_prmu: c_ptr(c_int) = tupleToCptr(parent.prmu);

    var lb_begin = c_malloc(c_int, JOBS);
    var BEGINEND: c_int = -1;

    lb1_children_bounds(lb1_data, c_prmu, parent.limit1:c_int, parent.limit2:c_int,
      lb_begin, c_nil, c_nil, c_nil, BEGINEND);

    c_free(c_prmu);

    // Treatment of childs
    for i in parent.limit1+1..parent.limit2-1 {

      if (parent.depth + 1 == jobs){ // if child leaf
        num_sol += 1;

        if (lb_begin[parent.prmu[i]] < best_thread){ // if child feasible
          best_locale = best_thread;
          best.write(lb_begin[parent.prmu[i]]);
        }
      } else { // if not leaf
        if (lb_begin[parent.prmu[i]] < best_thread){ // if child feasible
          var child = new Node(parent);
          child.depth += 1;

          if (side == 0){ // if forward
            child.limit1 += 1;
            child.prmu[child.limit1] <=> child.prmu[i];
          } else if (side == 1){ // if backward
            child.limit2 -= 1;
            child.prmu[child.limit2] <=> child.prmu[i];
          }

          childList.append(child);
          tree_loc += 1;
        }
      }

    }

    c_free(lb_begin);

    return childList;
  }

  proc fsp_simple_m_search_multi_node(const instance: int(8), const side: int,
    const dbgProfiler: bool, const dbgDiagnostics: bool, const printExploredTree: bool,
    const printExploredSol: bool, const printMakespan: bool, const lb: string,
    const saveTime: bool, const activeSet: bool): void
  {
    // FSP data
    var jobs: c_int = taillard_get_nb_jobs(instance);
    var machines: c_int = taillard_get_nb_machines(instance);

    var lb1_data: c_ptr(bound_data) = new_bound_data(jobs, machines);
    taillard_get_processing_times_d(lb1_data, instance);
    fill_min_heads_tails(lb1_data);

    // Global variables (best solution found and termination)
    var best: atomic int = setOptimal(instance);
    const PrivateSpace: domain(1) dmapped Private(); // map each index to a locale
    var eachLocaleTermination: [PrivateSpace] atomic bool = false;
    allLocalesBarrier.reset(here.maxTaskPar); // configuration of the global barrier

    // Counters and timers (for analysis)
    var eachExploredTree: [PrivateSpace] int = 0;
    var eachExploredSol: [PrivateSpace] int = 0;
    var counter_termination: atomic int = 0;
    var timers: [0..#numLocales, 0..#here.maxTaskPar, 0..5] real;
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

    //print_instance(machines, jobs, times);
    print_settings(instance, best.read(), lb, side);

    // ===============
    // INITIALIZATION
    // ===============

    var bag = new DistBag(Node, targetLocales = Locales);
    var root = new Node();

    if activeSet {
      /*
        An initial set is sequentially computed and distributed across locales.
        We require at least 2 nodes per thread.
      */
      var initSize: int = 2 * here.maxTaskPar * numLocales;
      var initList: list(Node);
      initList.append(root);

      var best_thread, best_locale: int = best.read();

      // Computation of the initial set
      while (initList.size < initSize) {
        var parent: Node = initList.pop();

        {
          var childList: list(Node) = decompose(parent, eachExploredTree[0], eachExploredSol[0],
            jobs, machines, side, best, best_thread, best_locale, lb1_data);

          for elt in childList do initList.insert(0, elt);
        }
      }

      // Static distribution of the set
      var seg: int = 0;
      var loc: int = 0;
      for elt in initList {
        on Locales[loc % numLocales] do bag.add(elt, seg);
        loc += 1;
        if (loc % numLocales == 0) {
          loc = loc % numLocales;
          seg += 1;
        }
        if (seg == here.maxTaskPar) then seg = 0;
      }

      initList.clear();
    }
    else {
      /*
        In that case, there is only one node in the bag (thread 0 of locale 0).
      */
      bag.add(root, 0);
    }

    writeln("\nInitial state of the bag (locale x thread):");
    for loc in Locales do on loc {
      writeln(bag.bag!.segments.nElems);
    }

    globalTimer.start();

    // =====================
    // PARALLEL EXPLORATION
    // =====================

    coforall loc in Locales with (ref timers, const jobs, const machines, const instance) do on loc {

      var lb1_data: c_ptr(bound_data) = new_bound_data(jobs, machines);
      taillard_get_processing_times_d(lb1_data, instance);
      fill_min_heads_tails(lb1_data);

      // Local variables (best solution found and termination)
      var best_locale: int = setOptimal(instance);
      var allThreadsEmptyFlag: atomic bool = false;
      var globalTerminationFlag: atomic bool = false;
      var eachThreadTermination: [0..#here.maxTaskPar] atomic bool = false;

      // Counters and timers (for analysis)
      var eachLocalExploredTree: [0..#here.maxTaskPar] int = 0;
      var eachLocalExploredSol: [0..#here.maxTaskPar] int = 0;
      var localTimer: Timer;

      localTimer.start();

      coforall tid in 0..#here.maxTaskPar with (ref best_locale, ref timers) {

        // Thread variables (best solution found)
        var best_thread: int = best_locale;

        // Counters and timers (for analysis)
        var count, counter: int = 0;
        var terminationTimer, decomposeTimer, readTimer, removeTimer: Timer;

        allLocalesBarrier.barrier(); // synchronization of threads

        while true do {
          counter += 1;

          // Check if the global termination flag is set or not
          terminationTimer.start();
          if (counter % 10000 == 0) {
            if globalTerminationFlag.read() {
              //writeln("loc/thread ", here.id, " ", tid, " breaks");
              terminationTimer.stop();
              break;
            }
          }
          terminationTimer.stop();

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
          if (hasWork != 1) then eachThreadTermination[tid].write(true);
          else {
            eachThreadTermination[tid].write(false);
            eachLocaleTermination[here.id].write(false);
          }

          if (hasWork == -1) {
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
          else if (hasWork == 0) {
            terminationTimer.stop();
            continue;
          }
          terminationTimer.stop();

          // Decompose an element
          decomposeTimer.start();
          {
            var childList: list(Node) = decompose(parent, eachLocalExploredTree[tid], eachLocalExploredSol[tid],
              jobs, machines, side, best, best_locale, best_thread, lb1_data);

            bag.addBulk(childList, tid);
          }
          decomposeTimer.stop();

          // Read the best solution found so far
          readTimer.start();
          if (tid == 0) {
            count += 1;
            if (count % 10000 == 0) then best_locale = best.read();
          }

          best_thread = best_locale;
          readTimer.stop();
        }

        timers[loc.id, tid, 0] = loc.id;
        timers[loc.id, tid, 1] = tid;
        timers[loc.id, tid, 3] = decomposeTimer.elapsed(TimeUnits.seconds);
        timers[loc.id, tid, 4] = terminationTimer.elapsed(TimeUnits.seconds);
        timers[loc.id, tid, 2] = removeTimer.elapsed(TimeUnits.seconds);
        timers[loc.id, tid, 5] = readTimer.elapsed(TimeUnits.seconds);
      } // end coforall threads

      localTimer.stop();

      eachExploredTree[here.id] += (+ reduce eachLocalExploredTree);
      eachExploredSol[here.id] += (+ reduce eachLocalExploredSol);
    } // end coforall locales

    globalTimer.stop();

    free_bound_data(lb1_data);
    //bag.clear();

    // ========
    // OUTPUTS
    // ========

    writeln("\nExploration terminated.");

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

    /* if saveTime { */
    {
      var tup = ("./ta",instance:string,"_chpl_",(+ reduce eachExploredTree):string,"_",lb,"_dist.txt");
      var path = "".join(tup);
      save_time(numLocales:c_int, globalTimer.elapsed(TimeUnits.seconds):c_double, path.c_str());
      /* save_time(here.maxTaskPar:c_int, globalTimer.elapsed(TimeUnits.seconds):c_double, path.c_str()); */
    }
    /* } */

    {
      var tup = ("./ta",instance:string,"_chpl_",(+ reduce eachExploredTree):string,"_",lb,"_",numLocales:string,"n_subtimes.txt");
      var path = "".join(tup);
      save_subtimes(path, timers);
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

    /* writeln("\nlocale\tthread\t(remove, decompose, termination, read):");
    writeln("=====");
    for loc in 0..#numLocales {
      for tid in 0..#here.maxTaskPar {
        writeln(loc, "\t", tid, "\t", timers[loc, tid, ..]);
      }
      writeln("=====");
    } */

    //writeln("\nNumber of global termination detection: ", counter_termination.read());
    print_results(eachExploredTree, eachExploredSol, globalTimer, best.read());
  }

}
