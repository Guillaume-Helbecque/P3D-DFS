module Instance
{
  use CTypes;

  class Instance
  {
    var name: string;

    proc get_nb_jobs(): c_int
    {
      halt("Error - get_nb_jobs() not implemented");
    }

    proc get_nb_machines(): c_int
    {
      halt("Error - get_nb_machines() not implemented");
    }

    proc get_data(d: c_ptr(c_int))
    {
      halt("Error - get_data() not implemented");
    }

    proc get_best_ub(): int
    {
      halt("Error - get_best_ub() not implemented");
    }
  }
}
