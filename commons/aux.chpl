module aux
{
  use CTypes;
  use IO;

  require "c_sources/aux.c", "c_headers/aux.h";
  extern proc swap(ref a: c_int, ref b: c_int): void;
	extern proc save_time(numTasks: c_int, time: c_double, path: c_string): void;

  proc save_tables(const path: string, const table: [] real): void
  {
    try! {
      var f: file = open(path, ioMode.cw);
      var channel = f.writer();
      channel.write(table);
      channel.close();
      f.close();
    }
  }

  proc common_help_message(): void
  {
    writeln("\n    usage:  main.o [parameter value] ...");
    writeln("\n  General Parameters:\n");
    writeln("   --mode                str   parallel execution mode (multicore, distributed)");
    writeln("   --activeSet           bool  computes and distributes an initial set of elements");
    writeln("   --saveTime            bool  save processing time in a file");
    writeln("   --help (or -h)              this message");
  }
}
