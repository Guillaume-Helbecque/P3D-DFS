use IO;
use List;
use Path;

use Problem;

class Problem_Knapsack : Problem
{
  var name: string;         // file name
  var N: int;               // number of items
  var W: int;               // maximum weight of the bag
  var profit: [0..#N] int;  // items' profit
  var weight: [0..#N] int;  // items' weight

  var ub_init: string;

  // initialisation from a file
  proc init(const fileName: string, const ub: string): void
  {
    this.name = fileName;

    var path_dir = "./benchmarks/Knapsack/instances/";
    if (fileName[0..5] == "knapPI") then
      //TODO: differentiate small_coeff from large_coeff etc.
      path_dir = "./benchmarks/Knapsack/instances/data_Pisinger/small_coeff/";
    var tup = (path_dir, fileName);
    var path = "".join(tup);

    var f = open(path, ioMode.r);
    var channel = f.reader();

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

    if (ub == "opt" || ub == "inf") then this.ub_init = ub;
    else halt("Error - Unsupported initial upper bound");
  }

  // initialisation from parameters
  proc init(const file_name: string, const n: int, const w: int, const pr: [] int,
    const we: [] int, const ub: string): void
  {
    this.name    = file_name;
    this.N       = n;
    this.W       = w;
    this.profit  = pr;
    this.weight  = we;
    this.ub_init = ub;
  }

  override proc copy()
  {
    return new Problem_Knapsack(this.name, this.N, this.W, this.profit, this.weight,
      this.ub_init);
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
    ref max_depth: int, best: atomic int, ref best_task: int): list
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
          if ((best_task < child.profit) && (best.read() < child.profit)) { // improve optimum
            best_task = child.profit;
            best.write(child.profit);
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

  override proc setInitUB(): int
  {
    if (this.ub_init == "inf") {
      return 0;
    }
    else {
      if (this.name == "default.txt") then return 1458;
      else { // Pisinger's instances
        const path = "./benchmarks/Knapsack/instances/data_Pisinger/small_coeff/knapPI_optimal.txt";

        var f = open(path, ioMode.r);
        var channel = f.reader();

        var file = channel.read([0..480, 0..1] string);

        channel.close();
        f.close();

        return file[file[..,0].find(splitExt(this.name)[0]),1]:int;
      }
    }
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
    writeln("\n  initial upper bound: ", setInitUB());
    writeln("=================================================");
  }

  override proc print_results(const subNodeExplored: [] int, const subSolExplored: [] int,
    const subDepthReached: [] int, const best: int, const elapsedTime: real): void
  {
    var treeSize: int = (+ reduce subNodeExplored);
    var nbSol: int = (+ reduce subSolExplored);
    var par_mode: string = if (numLocales == 1) then "tasks" else "locales";

    writeln("\n=================================================");
    writeln("Optimum found: ", best);
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
    writeln("   --name   str   file containing the data\n");
    writeln("   --ub     str   upper bound initialization (opt, inf)\n");
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
