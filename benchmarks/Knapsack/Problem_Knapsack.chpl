use IO;
use CTypes;
use List;
use Path;

use Problem;
use Instances;

require "../../commons/c_sources/util.c", "../../commons/c_headers/util.h";
extern proc swap(ref a: c_int, ref b: c_int): void;

class Problem_Knapsack : Problem
{
  var name: string;        // file name
  var N: int;              // number of items
  var W: int;              // maximum weight of the bag
  var profit: c_ptr(c_int); //[0..#N] int; // items' profit
  var weight: c_ptr(c_int); //[0..#N] int; // items' weight

  // TODO: put an "s" at "profit" and "weight".

  var lb_init: string;
  var initLB: int;

  // initialisation
  proc init(const fileName: string, const n, const r, const t, const id, const s,
    const lb: string): void
  {
    if (fileName == "") {
      // initialisation from parameters (Pisinger's instances)
      const inst = new Instance_Pisinger(n, r, t, id, s);

      this.name = inst.name;
      this.N = inst.get_nb_items();
      this.W = inst.get_capacity();
      this.profit = allocate(c_int, n);
      this.weight = allocate(c_int, n);
      inst.get_profits(this.profit);
      inst.get_weights(this.weight);

      this.lb_init = lb;

      if (lb == "opt") then this.initLB  = inst.get_best_lb();
      else if (lb == "inf") then this.initLB = 0;
      else halt("Error - Unsupported initial lower bound");
    }
    else {
      // initialisation from a file (user-defined instances)
      this.name = fileName;

      var path_dir = "./benchmarks/Knapsack/instances/";
      var path = path_dir + fileName;

      var f = open(path, ioMode.r);
      var channel = f.reader(locking=false);

      this.N = channel.read(int);
      this.W = channel.read(int);
      var a = channel.read([0..#this.N] c_int);
      var b = channel.read([0..#this.N] c_int);
      this.profit = c_ptrTo(a);
      this.weight = c_ptrTo(b);

      channel.close();
      f.close();

      this.lb_init = lb;
      if (lb == "opt") {
        // TODO: read the optimum from a file.
        if (this.name == "default.txt") then this.initLB = 1458;
        // TODO: add support for user defined instances.
      }
      else if (lb == "inf") then this.initLB = 0;
      else halt("Error - Unsupported initial lower bound");
    }

    /*
      NOTE: The bounding operator assumes that the items are sorted in decreasing
      order according to the ratio profit / weight.
    */
    sortItems(this.N, this.weight, this.profit);
  }

  // copy-initialisation
  proc init(const file_name: string, const n: int, const w: int, const pr: c_ptr(c_int),
    const we: c_ptr(c_int), const lb: string, const init_lb: int): void
  {
    this.name    = file_name;
    this.N       = n;
    this.W       = w;
    this.profit  = pr;
    this.weight  = we;
    this.lb_init = lb;
    this.initLB  = init_lb;
  }

  override proc copy()
  {
    return new Problem_Knapsack(this.name, this.N, this.W, this.profit, this.weight,
      this.lb_init, this.initLB);
  }

  proc computeBound(type Node, const n: Node)
  {
    var remainingWeight = this.W - n.weight;
    var bound = n.profit:real;

    for i in n.depth..this.N-1 {
      if (remainingWeight >= this.weight[i]) {
        bound += this.profit[i];
        remainingWeight -= this.weight[i];
      } else {
        bound += remainingWeight * (this.profit[i]:real / this.weight[i]:real);
        break;
      }
    }

    return bound;
  }

  override proc decompose(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
    ref max_depth: int, ref best: int, lock: sync bool, ref best_task: int): list(?)
  {
    var children: list(Node);

    for i in 0..1 {
      var child = new Node(parent);
      child.depth += 1;
      child.items[parent.depth] = i:uint(32);
      child.weight += i*this.weight[parent.depth];
      child.profit += i*this.profit[parent.depth];

      if (child.weight <= this.W) {
        if (child.depth == this.N) { // leaf
          num_sol += 1;

          if (best_task < child.profit) {
            best_task = child.profit;
            lock.readFE();
            if (best < child.profit) then best = child.profit;
            else best_task = best;
            lock.writeEF(true);
          }
        }
        else {
          if (best_task < /* child.profit + */ computeBound(Node, child)) { // bounding and pruning
            children.pushBack(child);
            tree_loc += 1;
          }
        }
      }
    }

    return children;
  }

  override proc getInitBound(): int
  {
    return this.initLB;
  }

  // =======================
  // Utility functions
  // =======================

  override proc print_settings(): void
  {
    writeln("\n=================================================");
    writeln("Resolution of the 0/1-Knapsack instance: ", this.name);
    writeln("  number of items: ", this.N);
    writeln("  capacity of the bag: ", this.W);
    writeln("  items's profit: ", this.profit);
    writeln("  items's weight: ", this.weight);
    writeln("\n  initial lower bound: ", this.initLB);
    writeln("=================================================");
  }

  override proc print_results(const subNodeExplored: [] int, const subSolExplored: [] int,
    const subDepthReached: [] int, const best: int, const elapsedTime: real): void
  {
    var treeSize: int = (+ reduce subNodeExplored);
    var nbSol: int = (+ reduce subSolExplored);
    var par_mode: string = if (numLocales == 1) then "tasks" else "locales";

    writeln("\n=================================================");
    const is_better = if (best > this.initLB) then " (improved)"
                                              else " (not improved)";
    writeln("Optimum found: ", best, is_better);
    writeln("Size of the explored tree: ", treeSize);
    /* writeln("Size of the explored tree per locale: ", sizePerLocale); */
    writeln("% of the explored tree per ", par_mode, ": ", 100 * subNodeExplored:real / treeSize:real);
    writeln("Number of explored solutions: ", nbSol);
    /* writeln("Number of explored solutions per locale: ", numSolPerLocale); */
    writeln("Elapsed time: ", elapsedTime, " [s]");
    writeln("=================================================\n");
  }

  override proc output_filepath(): string
  {
    return "./chpl_knapsack_" + splitExt(this.name)[0] + ".txt";
  }

  override proc help_message(): void
  {
    writeln("\n  Knapsack Benchmark Parameters:\n");
    writeln("   --lb     str   lower bound initialization (opt, inf)\n");
    writeln("   For user-defined instances:\n");
    writeln("    --inst   str   file containing the data\n");
    writeln("   For Pisinger's instances:\n");
    writeln("    --n      int   number of items");
    writeln("    --r      int   range of coefficients");
    writeln("    --t      int   type of instance (between 1 and 16, except 10)");
    writeln("    --id     int   instance index");
    writeln("    --s      int   number of tests in series\n");
  }

} // end class

/*
  This function is used to sort the items in decreasing order according to the
  ratio profit / weight.
*/
proc sortItems(const n, w: c_ptr(c_int), p: c_ptr(c_int))
{
  var r: [0..#n] real;
  for i in 0..#n do r[i] = p[i]:real / w[i]:real;

  for i in 0..#n {
    var max = (max reduce r[i..]);
    var max_id = r[i..].find(max);
    r[i] <=> r[max_id];
    swap(w[i], w[max_id]);
    swap(p[i], p[max_id]);
  }
}
