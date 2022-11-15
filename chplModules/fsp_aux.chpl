module fsp_aux
{
  use Time;
  use CTypes;
  use fsp_node;
  use IO;

  // Runtime constant: are the leaves printed ?
  config const display: bool = false;

  proc print_settings(const instance: int(8), const incumbent: int, const lb: string, const side: int): void
  {
    writeln("\n=================================");
    writeln("Taillard's instance: Ta", instance);
    writeln("Initial incumbent: ", incumbent);
    writeln("Lowerbound: ", lb);
    writeln("Branching rules: ", (1-side)*"forward" + side*"backward");
    writeln("=================================");
  }

  proc print_results(const sizePerLocale: [0..#numLocales] int, const numSolPerLocale: [0..#numLocales] int,
    const timer: Timer, const best: int): void
  {
    var size: int = (+ reduce sizePerLocale);
    var numSol: int = (+ reduce numSolPerLocale);

    writeln("\n=================================");
    writeln("Size of the explored tree: ", size);
    /* writeln("Size of the explored tree per locale: ", sizePerLocale); */
    writeln("% of the explored tree per locale: ", 100 * sizePerLocale:real / size:real);
    /* writeln("Number of explored solutions: ", numSol); */
    /* writeln("Number of explored solutions per locale: ", numSolPerLocale); */
    /* writeln("Optimal makespan: ", best); */
    writeln("Elapsed time: ", timer.elapsed(TimeUnits.seconds), " [s]");
    writeln("=================================\n");
  }

  // Print a leaf
  /* proc printLeaf(n: Node): void
  {
    if display then writeln(n.depth, " -- ", JOBS, ", ", n.prmu);
  } */

  // Return the best solution known of the given Taillard instance
  proc setOptimal(const instance: int(8)): int
  {
    var optimal: [1..120] int =  [1278, 1359, 1081, 1293, 1235, 1195, 1234, 1206, 1230, 1108,            // 20x5
                                  1582, 1659, 1496, 1377, 1419, 1397, 1484, 1538, 1593, 1591,            // 20x10
                                  2297, 2099, 2326, 2223, 2291, 2226, 2273, 2200, 2237, 2178,            // 20x20

                                  2724, 2834, 2621, 2751, 2863, 2829, 2725, 2683, 2552, 2782,            // 50x5
                                  2991, 2867, 2839, 3063, 2976, 3006, 3093, 3037, 2897, 3065,            // 50x10
                                  3850, 3704, 3640, 3723, 3611, 3681, 3704, 3691, 3743, 3756,            // 50x20

                                  5493, 5268, 5175, 5014, 5250, 5135, 5246, 5094, 5448, 5322,            // 100x5
                                  5770, 5349, 5676, 5781, 5467, 5303, 5595, 5617, 5871, 5845,            // 100x10
                                  6202, 6183, 6271, 6269, 6314, 6364, 6268, 6401, 6275, 6434,            // 100x20

                                  10862, 10480, 10922, 10889, 10524, 10329, 10854, 10730, 10438, 10675,  // 200x10
                                  11195, 11203, 11281, 11275, 11259, 11176, 11360, 11334, 11192, 11284,  // 200x20

                                  26040, 26520, 26371, 26456, 26334, 26477, 26389, 26560, 26005, 26457]; // 500x20

    if ((instance < 1) || (instance > 120)) {
      writeln("Unknown Taillard instance");
      return 99999;
    } else {
      return optimal[instance];
    }
  }

  proc fsp_helpMessage(): void
  {
    writeln("\n  FSP Benchmark Parameters:\n");
    writeln("   --instance  int   Taillard instance (0-120)");
    writeln("   --lb        str   lowerbound function (simple_m, simple_mn, johnson)");
    writeln("   --side      int   branching side (0: forward, 1: backward)");
  }
}
