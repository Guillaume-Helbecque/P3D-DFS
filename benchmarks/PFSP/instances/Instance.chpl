module Instance
{
  use CTypes;
  use Header_chpl_c_PFSP;

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

    proc get_data(lbd1: c_ptr(bound_data))
    {
      halt("Error - get_data() not implemented");
    }

    proc get_ub(): int
    {
      halt("Error - get_ub() not implemented");
    }
  }
}
