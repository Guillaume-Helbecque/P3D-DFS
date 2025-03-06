use IO;
use Path;
use CTypes;
use Instance;

class Instance_VRF : Instance
{
  var jobs: c_int;
  var machines: c_int;
  var data: c_ptr(c_int);

  proc init(const fileName: string)
  {
    this.name = fileName;
    var tup = ("./benchmarks/PFSP/instances/data_VRF/", fileName);
    var path = "".join(tup);

    var f = open(path, ioMode.r);
    var channel = f.reader(locking=false);

    this.jobs = channel.read(c_int);
    this.machines = channel.read(c_int);

    this.data = allocate(c_int, this.jobs*this.machines);
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

  proc deinit()
  {
    deallocate(data);
  }

  override proc get_nb_jobs(): c_int
  {
    return this.jobs;
  }

  override proc get_nb_machines(): c_int
  {
    return this.machines;
  }

  override proc get_data(d: c_ptr(c_int))
  {
    for i in 0..#this.jobs*this.machines do d[i] = this.data[i];
  }

  override proc get_best_ub(): int
  {
    const path = "./benchmarks/PFSP/instances/data_VRF/VFR_upper_lower_bounds.txt";

    var f = open(path, ioMode.r);
    var channel = f.reader(locking=false);

    var file = channel.read([0..240, 0..2] string);

    channel.close();
    f.close();

    return file[file[..,0].find(splitExt(this.name)[0]),1]:int;
  }
}
