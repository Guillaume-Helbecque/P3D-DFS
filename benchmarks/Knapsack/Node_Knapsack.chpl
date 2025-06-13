module Node_Knapsack
{
  config param maxItems: int = 100;

  record Node_Knapsack
  {
    var depth: int;
    var items: maxItems*uint(32);
    var weight: int;
    var profit: int;
    var bound: real;

    // default-initializer
    proc init()
    {}

    // root-initializer
    proc init(problem)
    {
      this.bound = max(real);
      init this;
    }

    // copy-initializer
    proc init(other: Node_Knapsack)
    {
      this.depth  = other.depth;
      this.items  = other.items;
      this.weight = other.weight;
      this.profit = other.profit;
      this.bound  = other.bound;
    }

    proc deinit()
    {}
  }
}
