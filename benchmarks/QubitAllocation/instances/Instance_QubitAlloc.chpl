use Instance;
use IO;

class Instance_QubitAlloc : Instance
{
  var filenameInter: string;
  var filenameDist: string;
  var n: int(32);
  var dom: domain(2, idxType = int(32));
  var F: [dom] int(32);
  var N: int(32);
  var D: [dom] int(32);

  proc init(filenameInter, filenameDist)
  {
    init this;

    var f = open("./benchmarks/QubitAllocation/instances/data_QubitAlloc/inter/" + filenameInter + ".csv", ioMode.r);
    var channel = f.reader(locking=false);

    channel.read(this.n);
    this.dom = {0..<this.n, 0..<this.n};
    channel.read(this.F);

    channel.close();
    f.close();

    f = open("./benchmarks/QubitAllocation/instances/data_QubitAlloc/dist/" + filenameDist + ".csv", ioMode.r);
    channel = f.reader(locking=false);

    channel.read(this.N);
    assert(this.n <= this.N, "More logical qubits than physical ones");
    this.dom = {0..<this.N, 0..<this.N};
    channel.read(this.D);

    channel.close();
    f.close();
  }

  override proc get_nb_entities(): int(32)
  {
    return this.n;
  }

  override proc get_nb_sites(): int(32)
  {
    return this.N;
  }

  override proc get_entities(ref E)
  {
    E = this.F;
  }

  override proc get_sites(ref S)
  {
    S = this.D;
  }

  override proc get_best_ub(): int
  {
    return 0;
  }
}
