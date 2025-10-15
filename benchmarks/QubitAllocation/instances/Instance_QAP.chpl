use Instance;
use IO;

class Instance_QAP : Instance
{
  var n: int(32);
  var dom: domain(2, idxType = int(32));
  var facilities: [dom] int(32);
  var locations: [dom] int(32);

  proc init(filename) {
    this.name = filename;

    init this;

    var f = open("./benchmarks/QubitAllocation/instances/data_QAP/" + filename + ".csv", ioMode.r);
    var channel = f.reader(locking=false);

    channel.read(this.n);
    this.dom = {0..<this.n, 0..<this.n};
    channel.read(this.facilities);
    channel.read(this.locations);

    channel.close();
    f.close();
  }

  override proc get_nb_entities(): int(32)
  {
    return this.n;
  }

  override proc get_nb_sites(): int(32)
  {
    return this.n;
  }

  override proc get_entities(ref E)
  {
    E = this.facilities;
  }

  override proc get_sites(ref S)
  {
    S = this.locations;
  }
}
