/*
 * P3D-DFS - Custom Problem Template
 *
 * This file provides a starting point for integrating your own
 * optimization problem into the generic Branch-and-Bound skeletons.
 *
 * Getting started:
 *   1. Copy this file and rename it to main_<yourproblem>.chpl.
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

    // default initializer
    proc init()
    {
      // TODO: Initialize an empty node.
    }

    // root initializer
    proc init(problem)
    {
      // TODO: Initialize the root node using the problem instance.
    }

    // copy initializer
    proc init(other: MyNode)
    {
      // TODO: Copy the state of another node.
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

    // TODO: Implement the required initialization and methods.
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
    var myProblem = new MyProblem(
      /* problem-specific options here */
    );

    // Launch the generic Branch-and-Bound search.
    // No modification is required here.
    run_search(args, MyNode, myProblem);

    return 0;
  }
}
