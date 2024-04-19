use IO;
use List;
use Path;

use Problem;

class Problem_Knapsack : Problem
{
  var name: string;        // file name
  var N: int;              // number of items
  var W: int;              // maximum weight of the bag
  var profit: [0..#N] int; // items' profit
  var weight: [0..#N] int; // items' weight

  var lb_init: string;
  var initLB: int;

  // initialisation from a file
  proc init(const fileName: string, const lb: string): void
  {
    this.name = fileName;

    var path_dir = "./benchmarks/Knapsack/instances/";
    if (fileName[0..5] == "knapPI") {
      var instanceType = fileName.split("_");
      if (instanceType[1]:int <= 9) then
      //TODO: differentiate small_coeff from large_coeff.
        path_dir += "data_Pisinger/small_coeff/";
      else
        path_dir += "data_Pisinger/small_coeff_hard/";
    }
    var path = path_dir + fileName;

    var f = open(path, ioMode.r);
    var channel = f.reader(locking=false);

    this.N = channel.read(int);
    this.W = channel.read(int);
    this.profit = channel.read([0..#this.N] int);
    this.weight = channel.read([0..#this.N] int);

    /*
      NOTE: The bounding operator assumes that the items are sorted in decreasing
      order according to the ratio profit / weight.
    */
    sortItems(this.weight, this.profit);

    channel.close();
    f.close();

    this.lb_init = lb;
    if (lb == "opt") {
      // TODO: read the optimum from a file.
      if (this.name == "default.txt") then this.initLB = 1458;
      // TODO: add support for user defined instances.
      else { // Pisinger's instances
        var path_dir = "./benchmarks/Knapsack/instances/data_Pisinger/";
        var instanceType = this.name.split("_");
        //TODO: differentiate small_coeff from large_coeff.
        if (instanceType[1]:int <= 9) then path_dir += "small_coeff/";
        else path_dir += "small_coeff_hard/";

        const path = path_dir + "knapPI_optimal.txt";

        var f = open(path, ioMode.r);
        var channel = f.reader(locking=false);

        var file = channel.read([0..480, 0..1] string);

        channel.close();
        f.close();

        this.initLB = file[file[..,0].find(splitExt(this.name)[0]),1]:int;
      }
    }
    else if (lb == "inf") then this.initLB = 0;
    else halt("Error - Unsupported initial lower bound");
  }

  // initialisation from parameters
  proc init(const file_name: string, const n: int, const w: int, const pr: [] int,
    const we: [] int, const lb: string, const init_lb: int): void
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
      child.items[parent.depth] = i;
      child.weight += i*this.weight[parent.depth];
      child.profit += i*this.profit[parent.depth];

      if (child.weight <= this.W) {
        if (child.depth == this.N) { // leaf
          num_sol += 1;

          lock.readFE();
          if ((best_task < child.profit) && (best < child.profit)) { // improve optimum
            best_task = child.profit;
            best = child.profit;
          }
          lock.writeEF(true);
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
    writeln("   --inst   str   file containing the data");
    writeln("   --lb     str   lower bound initialization (opt, inf)\n");
  }

} // end class

/*
  This function is used to sort the items in decreasing order according to the
  ratio profit / weight.
*/
proc sortItems(ref w, ref p)
{
  var r: [p.domain] real;
  for i in r.domain do r[i] = p[i]:real / w[i]:real;

  for i in r.domain {
    var max = (max reduce r[i..]);
    var max_id = r[i..].find(max);
    r[i] <=> r[max_id];
    w[i] <=> w[max_id];
    p[i] <=> p[max_id];
  }

}
