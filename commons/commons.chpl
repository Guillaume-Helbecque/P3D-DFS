module commons
{
  // Common modules
  use util;
  use search_sequential;
  use search_multicore;
  use search_distributed;

  // Common options
  config const mode: string    = "multicore"; // sequential, multicore, distributed
  config const findAll: bool   = false;
  config const activeSet: bool = false;
  config const saveTime: bool  = false;
}
