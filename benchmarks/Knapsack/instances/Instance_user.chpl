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

  override proc get_profits(): [] int
  {
    return this.profits;
  }

  override proc get_weights(): [] int
  {
    return this.weights;
  }

  override proc get_ub(): int
  {
    const path_dir = "./benchmarks/Knapsack/instances/data/";
    const (name, ext) = splitExt(this.name);
    // TODO: allow the user to specific the file where the ub is stored.
    var f = open(path_dir + name + "_optimal" + ext, ioMode.r);
    var channel = f.reader();

    var ub = channel.read(int);

    channel.close();
    f.close();

    return ub;
  }
}
