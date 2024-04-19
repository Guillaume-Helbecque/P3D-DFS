module Problem_UTS
{
  use CTypes;

  use Problem;
  use Header_chpl_c_UTS;

  param BIN: c_int      = 0;
  param GEO: c_int      = 1;
  param HYBRID: c_int   = 2;
  param BALANCED: c_int = 3;

  class Problem_UTS : Problem
  {
    /* Tree type
     *   Trees are generated using a Galton-Watson process, in
     *   which the branching factor of each node is a random
     *   variable.
     *
     *   The random variable can follow a binomial distribution
     *   or a geometric distribution. Hybrid tree are
     *   generated with geometric distributions near the
     *   root and binomial distributions towards the leaves.
     */
    var treeType: c_int;
    var b_0: c_double; // b
    var rootId: c_int; // r

    /*  Tree type BIN (BINOMIAL)
     *  The branching factor at the root is specified by b_0.
     *  The branching factor below the root follows an
     *     identical binomial distribution at all nodes.
     *  A node has m children with prob q, or no children with
     *     prob (1-q).  The expected branching factor is q * m.
     */
    var nonLeafBF: c_int; // m
    var nonLeafProb: c_double; // q

    /*  Tree type GEO (GEOMETRIC)
     *  The branching factor follows a geometric distribution with
     *     expected value b.
     *  The probability that a node has 0 <= n children is p(1-p)^n for
     *     0 < p <= 1. The distribution is truncated at MAXNUMCHILDREN.
     *  The expected number of children b = (1-p)/p.  Given b (the
     *     target branching factor) we can solve for p.
     *
     *  A shape function computes a target branching factor b_i
     *     for nodes at depth i as a function of the root branching
     *     factor b_0 and a maximum depth gen_mx.
     */
    var gen_mx: c_int; // d
    var shape_fn: c_int; // a

    /*  In type HYBRID trees, each node is either type BIN or type
     *  GEO, with the generation strategy changing from GEO to BIN
     *  at a fixed depth, expressed as a fraction of gen_mx
     */
    var shiftDepth: c_double; // f

    /* compute granularity - number of rng evaluations per tree node */
    var computeGranularity: c_int;

    proc init(const tree_type: c_int, const bf_0: c_double, const rootIdx: c_int, const nonLeafBFact: c_int,
      const nonLeafProba: c_double, const gen: c_int, const shape_fct: c_int, const shiftD: c_double,
      const gran: c_int): void
    {
      this.treeType           = tree_type;
      this.b_0                = bf_0;
      this.rootId             = rootIdx;
      this.nonLeafBF          = nonLeafBFact;
      this.nonLeafProb        = nonLeafProba;
      this.gen_mx             = gen;
      this.shape_fn           = shape_fct;
      this.shiftDepth         = shiftD;
      this.computeGranularity = gran;
    }

    override proc copy()
    {
      return new Problem_UTS(this.treeType, this.b_0, this.rootId, this.nonLeafBF,
        this.nonLeafProb, this.gen_mx, this.shape_fn, this.shiftDepth, this.computeGranularity);
    }

    override proc decompose(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, ref best: int, lock: sync bool, ref best_task: int): [] Node
    {
      var numChildren = uts_numChildren(parent, this.treeType, this.nonLeafBF, this.nonLeafProb,
        this.b_0, this.shape_fn, this.gen_mx, this.shiftDepth);

      var children: [0..#numChildren] Node;

      if (numChildren > 0) {
        c_decompose(parent, c_ptrTo(children), this.treeType, numChildren, this.gen_mx,
          this.shiftDepth, this.computeGranularity, tree_loc, max_depth);
      }
      else {
        num_sol += 1;
      }

      return children;
    }

    // No bounding in UTS
    override proc getInitBound(): int
    {
      return 0;
    }

    // =======================
    // Utility functions
    // =======================

    override proc print_settings(): void
    {
      writeln("\n=================================================");
      writeln("UTS - Unbalanced Tree Search");
      writeln("Tree type: ", this.treeType, " (", uts_trees_str[this.treeType]:string, ")");
      writeln("Tree shape parameters:");
      writeln("  root branching factor b_0 = ", this.b_0:int, ", root seed r = ", this.rootId);
      if (this.treeType == GEO || this.treeType == HYBRID) {
        writeln("  GEO parameters: gen_mx = ", this.gen_mx, ", shape function = ", this.shape_fn, " (", uts_geoshapes_str[this.shape_fn]:string, ")");
      }
      if (this.treeType == BIN || this.treeType == HYBRID) {
        var q = this.nonLeafProb;
        var m = this.nonLeafBF;
        var es: c_double = (1.0 / (1.0 - q * m));
        writeln("  BIN parameters: q = ", q, ", m = ", m, ", E(n) = ", q * m, ", E(s) = ", es);
      }
      if (this.treeType == HYBRID) {
        writeln("  HYBRID:  GEO from root to depth ", ceil(this.shiftDepth * this.gen_mx):int, ", then BIN");
      }
      if (this.treeType == BALANCED) {
        var exp_nodes: uint(64) = ((b_0**(this.gen_mx+1) - 1.0) / (b_0 - 1.0)):uint(64); /* geometric series */
        var exp_leaves: uint(64) = (b_0**this.gen_mx):uint(64);
        writeln("  BALANCED parameters gen_mx = ", this.gen_mx);
        writeln("    Expected size: ", exp_nodes, ", ", exp_leaves);
      }
      writeln("Random number generator: "); // TO COMPLETE
      writeln("Compute granularity: ", this.computeGranularity);
      writeln("=================================================");
    }

    override proc print_results(const subNodeExplored: [] int, const subSolExplored: [] int,
      const subDepthReached: [] int, const best: int, const elapsedTime: real): void
    {
      var treeSize: int = (+ reduce subNodeExplored);
      var nbLeaf: int   = (+ reduce subSolExplored);
      var maxDepth: int = (max reduce subDepthReached);
      var par_mode: string = if (numLocales == 1) then "tasks" else "locales";

      writeln("\n=================================");
      writeln("Size of the explored tree: ", treeSize);
      /* writeln("Size of the explored tree per locale: ", sizePerLocale); */
      writeln("% of the explored tree per ", par_mode, ": ", 100 * subNodeExplored:real / treeSize:real);
      writeln("Number of leaves explored: ", nbLeaf, " (", 100 * nbLeaf:real / treeSize:real, "%)");
      /* writeln("Number of explored solutions per locale: ", numSolPerLocale); */
      writeln("Tree depth: ", maxDepth);
      /* writeln("Optimal makespan: ", best); */
      writeln("Elapsed time: ", elapsedTime, " [s]");
      writeln("=================================\n");
    }

    override proc output_filepath(): string
    {
      var path = "./chpl_uts_" + uts_trees_str[this.treeType]:string +
                  "_b" + this.b_0:int:string + "_r" + this.rootId:string;

      if (this.treeType == BIN || this.treeType == HYBRID) then
        path += "_m" + this.nonLeafBF:string + "_q" + this.nonLeafProb:string;
      if (this.treeType == GEO || this.treeType == HYBRID) then
        path += "_a" + this.shape_fn:string + "_d" + this.gen_mx:string;
      if (this.treeType == HYBRID) then
        path += "_f" + this.shiftDepth:string;
      if (this.treeType == BALANCED) then
        path += "_d" + this.gen_mx:string;

      return path + "_g" + this.computeGranularity:string + ".txt";
    }

    override proc help_message(): void
    {
      writeln("\n  UTS Benchmark Parameters:\n");
      writeln("   --t   int       tree type (0: BIN, 1: GEO, 2: HYBRID, 3: BALANCED)");
      writeln("   --b   int       root branching factor");
      writeln("   --r   int       root seed 0 <= r < 2^31");
      writeln("   --a   int       GEO: tree shape function");
      writeln("   --d   int       GEO, BALANCED: tree depth");
      writeln("   --q   double    BIN: probability of non-leaf node");
      writeln("   --m   int       BIN: number of children for non-leaf node");
      writeln("   --f   double    HYBRID: fraction of depth for GEO -> BIN transition");
      writeln("   --g   int       granularity: number of rng_spawns per node");
    }

  } // end class

} // end module
