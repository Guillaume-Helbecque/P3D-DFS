module Problem_Knapsack
{
  use CTypes;
  use List;
  use Path;

  use Problem;
  use Instances;

  require "../../commons/c_sources/util.c", "../../commons/c_headers/util.h";
  extern proc swap(ref a: c_int, ref b: c_int): void;

  class Problem_Knapsack : Problem
  {
    var name: string;          // instance name
    var N: c_int;              // number of items
    var W: c_longlong;         // maximum weight of the bag
    var profits: c_ptr(c_int); // items' profit
    var weights: c_ptr(c_int); // items' weight

    var lb_init: string;
    var initLB: int;

    // initialisation
    proc init(const fileName: string, const n, const r, const t, const id, const s,
      const lb: string): void
    {
      // TODO: Is id > s allowed?

      var inst = new Instance();
      if (fileName == "") then inst = new Instance_Pisinger(n, r, t, id, s);
      else inst = new Instance_user(fileName);

      this.name = inst.name;
      this.N = inst.get_nb_items();
      this.W = inst.get_capacity();
      this.profits = allocate(c_int, n);
      this.weights = allocate(c_int, n);
      inst.get_profits(this.profits);
      inst.get_weights(this.weights);

      this.lb_init = lb;

      if (lb == "opt") then this.initLB = inst.get_best_lb();
      else if (lb == "inf") then this.initLB = 0;
      else {
        try! this.initLB = lb:int;

        // NOTE: If `lb` cannot be cast into `int`, an errow is thrown. For now, we cannot
        // manage it as only catch-less try! statements are allowed in initializers.
        // Ideally, we'd like to do this:

        /* try {
          this.initLB = lb:int;
        } catch {
          halt("Error - Unsupported initial lower bound");
        } */
      }

      /*
        NOTE: The bounding operator assumes that the items are sorted in decreasing
        order according to the ratio profit / weight.
      */
      sortItems(this.N, this.weights, this.profits);
    }

    // copy-initialisation
    proc init(const file_name: string, const n, const w, const pr: c_ptr(c_int),
      const we: c_ptr(c_int), const lb: string, const init_lb: int): void
    {
      this.name    = file_name;
      this.N       = n;
      this.W       = w;
      this.profits = pr;
      this.weights = we;
      this.lb_init = lb;
      this.initLB  = init_lb;
    }

    override proc copy()
    {
      return new Problem_Knapsack(this.name, this.N, this.W, this.profits, this.weights,
        this.lb_init, this.initLB);
    }

    proc computeBound(type Node, const n: Node)
    {
      var remainingWeight = this.W - n.weight;
      var bound = n.profit:real;

      for i in n.depth..this.N-1 {
        if (remainingWeight >= this.weights[i]) {
          bound += this.profits[i];
          remainingWeight -= this.weights[i];
        } else {
          bound += remainingWeight * (this.profits[i]:real / this.weights[i]:real);
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
        child.weight += i*this.weights[parent.depth];
        child.profit += i*this.profits[parent.depth];

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
      writeln("  items's profit: ", this.profits);
      writeln("  items's weight: ", this.weights);
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
}
