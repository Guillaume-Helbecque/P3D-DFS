/*
 * P3D-DFS - Custom Problem Template
 *
 * This file provides a starting point for integrating your own
 * optimization problem into the generic Branch-and-Bound skeletons.
 *
 * Getting started:
 *   1. Copy this file and rename it to main_<myproblem>.chpl.
 *   2. Implement the MyNode record.
 *   3. Implement the MyProblem class and its required operations.
 *   4. Configure your problem instance in main().
 *   5. Compile using make.
 *
 * Tip: Refer to the existing benchmarks for concrete implementations.
 */

module main_template
{
  use commons;
  use Problem;
  use List;

  /*
   * ============================================================
   * STEP 1 - Define your search tree node
   * ============================================================
   *
   * MyNode represents a partial solution in the B&B search tree.
   * Add any fields needed to describe the current search state.
   */

  record MyNode
  {
    // TODO: Declare your node-specific fields here.
    // Typical examples: the current depth, the partial solution built so far
    // (a permutation, a set of chosen items, ...), and any value that lets
    // you evaluate or extend the node cheaply (partial cost, remaining capacity, ...).
    // Keep the node small and free of heap-allocated data when possible:
    // nodes are copied and moved between tasks and locales very often.

    // Default initializer.
    // Creates an empty node. It is required by the data structures that
    // store nodes (pools, bags) to allocate space before nodes are filled in.
    proc init()
    {
      // TODO: Give every field a neutral default value (0, empty array, ...).
    }

    // Root initializer.
    // Creates the root of the search tree, i.e. the empty partial solution
    // from which the whole exploration starts. It is called once, in main().
    proc init(someArgs)
    {
      // TODO: Initialize the fields of the root node from the given
      // arguments (e.g. depth = 0, nothing chosen yet, full capacity).
    }

    // Copy initializer.
    // Creates a node identical to 'other'. It is used when a node is
    // duplicated, for example when a child is built from its parent.
    proc init(other: MyNode)
    {
      // TODO: Copy every field of 'other' into this node. Arrays and other
      // reference-like fields must be deep-copied, otherwise two nodes
      // would share (and corrupt) the same data.
    }
  }

  /*
   * ============================================================
   * STEP 2 - Define your optimization problem
   * ============================================================
   *
   * MyProblem stores the problem instance and its associated data.
   * It inherits from the generic Problem class.
   */

  class MyProblem : Problem
  {
    // TODO: Declare your problem-specific fields.
    // These are the read-only data of the instance (sizes, cost matrices,
    // weights, ...), plus any value you want to print in the settings or
    // results. Nodes must not store them: they live here, once per problem.

    // Returns a deep copy of the problem instance.
    // The search engine gives each locale (and possibly each task) its own
    // copy of the problem, so that the instance data can be read locally
    // without remote accesses or sharing between tasks.
    override proc copy()
    {
      // TODO: Build and return a new MyProblem holding a full copy of every
      // field of this instance (arrays included).
      compilerError("MyProblem.copy() not implemented");
    }

    // Explores one node of the search tree (the branching and pruning step).
    // Given a 'parent' node, it generates its children, discards those that
    // cannot lead to a better solution than the best one known, and returns
    // the remaining ones to be explored later. It also updates the search
    // statistics and the best solution found so far.
    //
    // Parameters:
    //   Node          type of the nodes of the tree (MyNode).
    //   parent        the node to decompose.
    //   tree_loc      counter of explored nodes: increment it for each node you generate/evaluate.
    //   num_sol       counter of solutions found: increment it when a complete solution is reached.
    //   max_depth     deepest level reached so far: update it when a deeper node is generated.
    //   bestCost      best cost found so far (shared); protected by 'lock'.
    //   lock          lock to take before modifying the shared 'bestCost'.
    //   bestCost_task local, lock-free copy of the best cost used for fast pruning checks.
    override proc decompose(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, ref bestCost: int, lock: sync bool, ref bestCost_task: int)
    {
      // TODO: Implement the decomposition in these steps:
      //   1. Create an empty list of children (List of Node).
      //   2. If 'parent' is a leaf (complete solution): compute its cost,
      //      increment 'num_sol', and if it improves on 'bestCost', update
      //      'bestCost' and 'bestCost_task' while holding 'lock'.
      //   3. Otherwise, for each possible branching choice:
      //        - build the child from a copy of 'parent',
      //        - compute its lower bound (minimization) or upper bound (maximization),
      //        - discard it if the bound is not better than 'bestCost_task' (pruning),
      //        - otherwise append it to the list, and update 'tree_loc' and 'max_depth'.
      //   4. Return the list of children.
      // The sign of the comparisons depends on whether you minimize or maximize.
      compilerError("MyProblem.decompose() not implemented");
    }

    // Returns the initial value of the best cost, before any exploration.
    // It is the starting upper bound (minimization) used to prune the tree:
    // the closer it is to the optimum, the more nodes are cut from the start.
    override proc getInitBound(): int
    {
      // TODO: Return one of the following:
      //   - a very large value (minimization) or very small one (maximization)
      //     if you have no information (e.g. max(int)),
      //   - a known optimal or best-known value, if you want to prove it quickly,
      //   - the cost of a solution given by a heuristic, for a good bound with no prior knowledge.
      compilerError("MyProblem.getInitBound() not implemented");
    }

    // Prints the settings of the run, before the search starts.
    // It reminds the user which instance and which parameters are used,
    // which is useful to make the output of a run self-explanatory.
    override proc print_settings(): void
    {
      // TODO: Print the main information of the run: instance name or size,
      // initial bound, and any problem-specific option that was set.
      compilerWarning("MyProblem.print_settings() not implemented");
    }

    // Prints the results of the run, after the search ends.
    // The generic engine calls it with the statistics it has gathered.
    //
    // Parameters:
    //   nodesExplored  total number of nodes explored.
    //   nbSol          number of solutions found.
    //   maxDepth       deepest level reached in the tree.
    //   bestCost       best (optimal) cost found.
    //   elapsedTime    wall-clock time of the search, in seconds.
    override proc print_results(const nodesExplored, const nbSol, const maxDepth,
      const bestCost: int, const elapsedTime: real): void
    {
      // TODO: Print the statistics above in a readable form. You can add
      // problem-specific information, e.g. the best solution itself
      // or the objective value in the units of your problem.
      compilerWarning("MyProblem.print_results() not implemented");
    }

    // Prints the help message for the problem-specific options.
    // It is shown with --help, after the generic options, so that the user
    // knows which 'config const' of this file can be set on the command line.
    override proc help_message(): void
    {
      // TODO: Print one line per option declared in this file (name,
      // meaning, default value, accepted values).
      compilerWarning("MyProblem.help_message() not implemented");
    }
  }

  /*
   * ============================================================
   * STEP 3 - Configure and launch the search
   * ============================================================
   *
   * Define any problem-specific configuration constants above
   * main() using Chapel's 'config const' mechanism.
   *
   * The generic run_search() procedure handles the selected
   * execution mode (sequential, multicore, or distributed).
   */

  // TODO: Add your problem-specific configuration options here.

  proc main(args: [] string): int
  {
    // TODO: Initialize your problem instance.
    var myProblem = new MyProblem(/* problem-specific options here */);
    // TODO: Initialize your root node.
    var root = new MyNode(/* args */);

    // Launch the generic Branch-and-Bound search.
    // No modification is required here.
    run_search(args, root, myProblem);

    return 0;
  }
}
