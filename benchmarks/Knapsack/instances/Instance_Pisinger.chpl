use IO;
use Path;
use CTypes;
use Instance;

require "../c_sources/Pisinger_genhard.c", "../c_headers/Pisinger_genhard.h";
extern proc generator(n: int, pp: c_ptr(c_int), ww: c_ptr(c_int), t: int, r: int, v: int, tests: int): int(64);

const s: c_int = 1000;

class Instance_Pisinger : Instance
{
  var n: int;
  var profits: [0..#n] c_int;
  var weights: [0..#n] c_int;
  var c: int;

  proc init(const fileName: string)
  {
    this.name = fileName;

    var compts = splitExt(fileName)[0].split("_");

    const t = compts[1]:int;
    if (t < 1 || t == 10 || t > 16) then halt("Error - Unknown instance type");

    this.n = compts[2]:int;

    const r = compts[3]:int;
    const i = compts[4]:int;

    this.c = generator(this.n, c_ptrTo(this.profits), c_ptrTo(this.weights), t, r, i, s);
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

  override proc get_profits(): [] c_int
  {
    return this.profits;
  }

  override proc get_weights(): [] c_int
  {
    return this.weights;
  }

  override proc get_ub(): int
  {
    var f = open("./benchmarks/Knapsack/instances/data/Pisinger_optimals.txt", ioMode.r);
    var channel = f.reader();

    var file = channel.read([0..#31800, 0..1] string);

    channel.close();
    f.close();

    var idx = file[..,0].find(splitExt(this.name)[0]);

    if (idx == -1) {
      warning("Optimal not found; setting it to 0 (\"inf\"). ");
      return 0;
    }

    return file[idx, 1]:int;
  }
}
