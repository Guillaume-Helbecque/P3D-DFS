use IO;
use CTypes;
use Instance;
use Header_chpl_c_PFSP;

class Instance_VFR : Instance
{
  var jobs: c_int;
  var machines: c_int;
  var data: c_ptr(c_int);

  proc init(const fileName: string)
  {
    this.name = fileName;
    var tup = ("./benchmarks/PFSP/instances/VFR/", this.name);
    var path = "".join(tup);

    var f = open(path, iomode.r);
    var channel = f.reader();

    this.jobs = channel.read(c_int);
    this.machines = channel.read(c_int);

    this.data = c_malloc(c_int, this.jobs*this.machines);
    var data1 = channel.read([0..#2*jobs*machines] c_int);
    var data2: [0..#jobs*machines] c_int = data1(1..#2*jobs*machines by 2);
    for j in 0..#machines {
      for i in 0..#jobs {
        this.data[i+j*jobs] = data2[j+i*machines];
      }
    }

    channel.close();
    f.close();
  }

  override proc get_nb_jobs(): c_int
  {
    return this.jobs;
  }

  override proc get_nb_machines(): c_int
  {
    return this.machines;
  }

  override proc get_data(lbd1: c_ptr(bound_data))
  {
    for i in 0..#this.jobs*this.machines do lbd1.deref().p_times[i] = this.data[i];
  }
}
