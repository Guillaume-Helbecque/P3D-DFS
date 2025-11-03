use Instance;
use IO;

class Instance_QAP : Instance
{
  var n: int(32);
  var dom: domain(2, idxType = int(32));
  var flow: [dom] int(32);
  var distance: [dom] int(32);

  proc init(filename) {
    this.name = filename;

    init this;

    var f = open("./benchmarks/QAP/instances/data_QAP/" + filename + ".csv", ioMode.r);
    var channel = f.reader(locking=false);

    channel.read(this.n);
    this.dom = {0..<this.n, 0..<this.n};
    channel.read(this.flow);
    channel.read(this.distance);

    channel.close();
    f.close();
  }

  override proc get_nb_facilities(): int(32)
  {
    return this.n;
  }

  override proc get_nb_locations(): int(32)
  {
    return this.n;
  }

  override proc get_flow(ref F)
  {
    F = this.flow;
  }

  override proc get_distance(ref D)
  {
    D = this.distance;
  }
}
