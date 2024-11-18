module main_template
{
  /*
    This module is a template designed to help users define their own problem and
    `Node` type. It is not intended to compile until it has been fully implemented.
  */

  use launcher;
  use Problem;

  record Node_template {
    // Define your `Node` type here
  }

  class Problem_template : Problem {
    override proc copy() {
      // Provide implementation of copy here
    }

    override proc decompose(type Node, const parent: Node, ref tree_loc: int, ref num_sol: int,
      ref max_depth: int, ref best: int, lock: sync bool, ref best_task: int) {
      // Provide implementation of decompose here
    }

    override proc getInitBound(): int {
      // Provide implementation of getInitBound here
    }
  }

  proc main(args: [] string): int {
    const pb = new Problem_template(); // initialize the problem
    const root = new Node_template(); // initialize the root node
    launcher(args, root, pb); // launch problem solving

    return 0;
  }
}
