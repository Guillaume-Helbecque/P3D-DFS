module fsp_simple_mn_bound_single_node
{
  use List;
  use Time;
  use CTypes;
  use PrivateDist;
  use VisualDebug;
  use CommDiagnostics;
  use DistributedBag;

  use aux;
  use fsp_node;
  use statistics;
  use fsp_aux_mlocale;
  use fsp_simple_aux_mlocale;
  use fsp_simple_chpl_c_headers;

  // Decompose a parent node and return the list of its feasible child nodes (SIMPLE O(MxN))
  proc decompose(const parent: Node, ref tree_loc: uint, ref num_sol: uint, const jobs: c_int, const machines: c_int,
    minTempsArr_s: c_ptr(c_int), minTempsDep_s: c_ptr(c_int), c_temps_s: c_ptr(c_int), side: int, incumbent_g: atomic uint): list
  {
    var childList: list(Node); // list containing the child nodes

    var incumbent_l: uint = incumbent_g.read();

    // Treatment of childs
    for i in parent.limit1+1..parent.limit2-1 {
      var child = new Node(parent);
      child.prmu[child.depth] <=> child.prmu[i]; // Chapel swap operator
      child.depth  += 1;
      child.limit1 += 1;

      var c_prmu: c_ptr(c_int) = tupleToCptr(child.prmu);

      var lowerbound: int = simple_mn_bornes_calculer(c_prmu, child.limit1:c_int, child.limit2:c_int,
        machines, jobs, minTempsArr_s, minTempsDep_s, c_temps_s);

      c_free(c_prmu);

      if (child.depth == jobs) { // if child leaf
        num_sol += 1;

        if (lowerbound < incumbent_l){ // if child feasible
          incumbent_g.write(lowerbound:uint);
        }
      } else { // if not leaf
        if (lowerbound < incumbent_l) { // if child feasible
          tree_loc += 1;
          childList.append(child);
        }
      }

    } // for childs

    return childList;
  }

  // Explore a tree
  proc fsp_simple_mn_search_single_node(const instance: int(8), const side: int,
    const dbgProfiler: bool, const dbgDiagnostics: bool, const printExploredTree: bool,
    const printExploredSol: bool, const printMakespan: bool, const lb: string,
    const saveTime: bool): void
  {
    // Global counters
    var num_sol: uint = 0:uint;
    var exploredTree: uint = 0:uint;
    var incumbent_g: atomic uint = setOptimal(instance);

    var jobs, machines: c_int;
    var times: c_ptr(c_int) = get_instance(machines, jobs, instance);
    print_instance(machines, jobs, times);

    remplirTempsArriverDepart(minTempsArr_s, minTempsDep_s, machines, jobs, times);

    //PROFILER
    if dbgProfiler {
      startVdebug("test");
      tagVdebug("init");
      writeln("Starting profiler");
    } //end of profiler

    if dbgDiagnostics {
      writeln("\n### Starting communication counter ###");
      startCommDiagnostics();
    }

    var globalTimer: Timer;
    globalTimer.start();

    // EXPLORATION OF THE SEARCH SPACE
    // The initial set is distributed across locales using 'balance()', and the
    // exploration of the tree is done in parallel.

    var bag = new DistBag(Node, targetLocales = Locales);
    var root = new Node();
    bag.add(root, 0);

    var eachExploredTree: [0..#here.maxTaskPar] uint = 0:uint;
    var eachExploredSol: [0..#here.maxTaskPar] uint = 0:uint;

    var eachTermination: [0..#here.maxTaskPar] atomic bool = true;

    coforall tid in 0..#here.maxTaskPar {

      // Exploration of the tree
      while true do {

        var (notEmpty, parent): (bool, Node) = bag.remove(tid);

        // Termination condition
        if !notEmpty { // if locally empty
          eachTermination[tid].write(false);
          if all_false(eachTermination) { // if globaly empty
            break;
          }
          continue;
        }
        else { // if locally not empty
          eachTermination[tid].write(true);
        }

        {
          var childList: list(Node) = decompose(parent, eachExploredTree[tid], eachExploredSol[tid],
            jobs, machines, minTempsArr_s, minTempsDep_s, times, side, incumbent_g);

          bag.addBulk(childList, tid);
        }

      } // end while
    } // end coforall tasks

    writeln("Exploration terminated.\n");

    exploredTree = (+ reduce eachExploredTree);
    num_sol = (+ reduce eachExploredSol);

    globalTimer.stop();

    bag.clear();

    if dbgProfiler {
      stopVdebug();
      writeln("### Debuging is done ###");
    }

    if dbgDiagnostics {
      writeln("### Stopping communication counter ###");
      stopCommDiagnostics();
      writeln("\n ### Communication results ### \n", getCommDiagnostics());
    }

    // OUTPUTS
    writeln("==========================");
    if printExploredTree then writeln("Size of the explored tree: ", exploredTree);
    if printExploredTree then writeln("Size of the explored tree per thread: ", eachExploredTree);
    if printExploredSol then writeln("Number of explored solutions: ", num_sol);
    if printMakespan then writeln("Best makespan: ", incumbent_g);
    writeln("Elapsed time: ", globalTimer.elapsed(TimeUnits.seconds), "s");

    if saveTime {
      var tup = ("./ta",instance:string,"_",lb,"_",side:string,".txt");
      var path = "".join(tup);
      save_time(here.maxTaskPar:c_int, globalTimer.elapsed(TimeUnits.seconds):c_double, path.c_str());
    }
    writeln("==========================");
  }

}
