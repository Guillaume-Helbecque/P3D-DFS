module main_knapsack
{
  use launcher;

  // Knapsack-specific modules
  use Node_Knapsack;
  use Problem_Knapsack;

  // Knapsack-specific option
  config const inst: string = "default.txt";
  config const lb: string   = "opt"; // opt, inf

  proc main(args: [] string): int
  {
    // Initialization of the problem
    const knapsack = new Problem_Knapsack(inst, lb);
    const root = new Node_Knapsack();
    launcher(args, root, knapsack);

    return 0;
  }
}
