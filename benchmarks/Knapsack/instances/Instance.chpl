module Instance
{
  use CTypes;

  class Instance
  {
    var name: string;

    proc get_nb_items(): int
    {
      halt("Error - get_nb_items() not implemented");
    }

    proc get_capacity(): int
    {
      halt("Error - get_capacity() not implemented");
    }

    proc get_profits(d: c_ptr(c_int))
    {
      halt("Error - get_profits() not implemented");
    }

    proc get_weights(d: c_ptr(c_int))
    {
      halt("Error - get_weights() not implemented");
    }

    proc get_best_lb(): int
    {
      halt("Error - get_best_lb() not implemented");
    }
  }
}
