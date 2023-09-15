use IO;
use Path;
use Instance;

class Instance_user : Instance
{
  var n: int;
  var c: int;
  var profits: [0..#n] int;
  var weights: [0..#n] int;

  proc init(const fileName: string)
  {
    this.name = fileName;

    var f = open("./benchmarks/Knapsack/instances/data/" + fileName, ioMode.r);
    var channel = f.reader();

    this.n = channel.read(int);
    this.c = channel.read(int);
    this.profits = channel.read([0..#this.n] int);
    this.weights = channel.read([0..#this.n] int);

    channel.close();
    f.close();
  }

  proc deinit() {}

  override proc get_nb_items(): int
  {
    return this.n;
  }

  override proc get_capacity(): int
  {
    return this.c;
  }

  override proc get_profits(): [0..#this.n] int
  {
    return this.profits;
  }

  override proc get_weights(): [] int
  {
    return this.weights;
  }

  override proc get_ub(): int
  {
    // TODO: read the optimum from a file + allow the user to specific the file
    // where the ub is stored.
    if (this.name == "default.txt") then return 1458;
    return 1458;
  }
}
