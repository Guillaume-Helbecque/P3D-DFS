use IO;
use Path;
use CTypes;
use Instance;

require "../c_sources/pisinger_genhard.c", "../c_headers/pisinger_genhard.h";
extern proc generator(n: c_int, pp: c_ptr(c_int), ww: c_ptr(c_int), typ: c_int,
  r: c_int, v: c_int, tests: c_int): c_int;

class Instance_Pisinger : Instance
{
  var nb_items: c_int;
  var typ: c_int;
  var profits: c_ptr(c_int);
  var weights: c_ptr(c_int);
  var capacity: c_int;

  proc init(const n: c_int, const r: c_int, const t: c_int, const id: c_int, const s: c_int)
  {
    this.name = "knapPI_" + t:string + "_" + n:string + "_" + r:string +
      "_" + id:string + ".txt";

    this.nb_items = n;
    this.typ = t;
    this.profits = allocate(c_int, n);
    this.weights = allocate(c_int, n);

    init this;

    this.capacity = generator(this.nb_items, this.profits, this.weights, this.typ, r, id, s);
  }

  proc deinit()
  {
    deallocate(this.profits);
    deallocate(this.weights);
  }

  override proc get_nb_items(): int
  {
    return this.nb_items;
  }

  override proc get_capacity(): int
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
    var path_dir = "./benchmarks/Knapsack/instances/data_Pisinger/";
    var instanceType = this.name.split("_");
    //TODO: differentiate small_coeff from large_coeff.
    if (instanceType[1]:int <= 9) then path_dir += "small_coeff/";
    else path_dir += "small_coeff_hard/";

    const path = path_dir + "knapPI_optimal.txt";

    var f = open(path, ioMode.r);
    var channel = f.reader(locking=false);

    var file = channel.read([0..480, 0..1] string);

    channel.close();
    f.close();

    return file[file[..,0].find(splitExt(this.name)[0]),1]:int;
  }
}
