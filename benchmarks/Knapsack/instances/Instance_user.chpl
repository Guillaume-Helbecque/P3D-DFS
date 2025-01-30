use IO;
use Path;
use CTypes;
use Instance;

class Instance_user : Instance
{
  var nb_items: c_int;
  var capacity: c_longlong;
  var profits: [0..#nb_items] c_int;
  var weights: [0..#nb_items] c_int;

  proc init(const fileName: string)
  {
    this.name = fileName;

    var path = "./benchmarks/Knapsack/instances/" + fileName;

    var f = open(path, ioMode.r);
    var channel = f.reader(locking=false);

    this.nb_items = channel.read(c_int);
    this.capacity = channel.read(c_longlong);
    this.profits = channel.read([0..#this.nb_items] c_int);
    this.weights = channel.read([0..#this.nb_items] c_int);

    channel.close();
    f.close();
  }

  override proc get_nb_items(): c_int
  {
    return this.nb_items;
  }

  override proc get_capacity(): c_longlong
  {
    return this.capacity;
  }

  override proc get_profits(d: c_ptr(c_int))
  {
    for i in 0..#this.nb_items do
      d[i] = this.profits[i];
  }

  override proc get_weights(d: c_ptr(c_int))
  {
    for i in 0..#this.nb_items do
      d[i] = this.weights[i];
  }

  override proc get_best_lb(): int
  {
    return 0;
  }
}
