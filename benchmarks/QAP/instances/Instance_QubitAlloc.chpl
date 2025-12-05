use Instance;
use IO;

class Instance_QubitAlloc : Instance
{
  var n: int(32);
  var dom: domain(2, idxType = int(32));
  var flow: [dom] int(32);
  var N: int(32);
  var distance: [dom] int(32);

  proc init(filenameInter, filenameDist)
  {
    init this;

    var f = open("./benchmarks/QAP/instances/data_QubitAlloc/inter/" + filenameInter + ".csv", ioMode.r);
    var channel = f.reader(locking=false);

    channel.read(this.n);
    this.dom = {0..<this.n, 0..<this.n};
    channel.read(this.flow);

    channel.close();
    f.close();

    f = open("./benchmarks/QAP/instances/data_QubitAlloc/dist/" + filenameDist + ".csv", ioMode.r);
    channel = f.reader(locking=false);

    channel.read(this.N);
    assert(this.n <= this.N, "More logical qubits than physical ones");
    this.dom = {0..<this.N, 0..<this.N};
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
    return this.N;
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
