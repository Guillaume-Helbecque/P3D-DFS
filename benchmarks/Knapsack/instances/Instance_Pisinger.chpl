use CTypes;
use Instance;

require "../c_sources/pisinger_genhard.c", "../c_headers/pisinger_genhard.h";
extern proc generator(n: c_int, pp: c_ptr(c_int), ww: c_ptr(c_int), typ: c_int,
  r: c_int, v: c_int, tests: c_int);

class Instance_Pisinger : Instance
{
  var nb_items: c_int;
  var typ: c_int;
  var profits: c_ptr(c_int);
  var weights: c_ptr(c_int);
  var capacity: c_int;

  proc init(const n: c_int, const r: c_int, const t: c_int, const id: c_int, const s: c_int)
  {
    this.nb_items = n;
    this.typ = t;
    this.profits = allocate(c_int, this.nb_items);
    this.weights = allocate(c_int, this.nb_items);

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
    return this.profits;
  }

  override proc get_weights(d: c_ptr(c_int))
  {
    return this.weights;
  }

  override proc get_best_lb(): int
  {
    return 0;
  }
}
