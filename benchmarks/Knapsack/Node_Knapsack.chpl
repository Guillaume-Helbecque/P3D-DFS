module Node_Knapsack
{
  config param maxItems: int = 100;

  record Node_Knapsack
  {
    var depth: int;
    var items: maxItems*uint(32);
    var weight: int;
    var profit: int;

    // default-initializer
    proc init()
    {}

    // root-initializer
    proc init(problem)
    {
      this.init();
    }

    // copy-initializer
    proc init(other: Node_Knapsack)
    {
      this.depth = other.depth;
      this.items = other.items;
      this.weight = other.weight;
      this.profit = other.profit;
    }

    proc deinit()
    {}
  }
}
