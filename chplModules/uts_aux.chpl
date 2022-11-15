module uts_aux
{
  use Time;

  require "../src/uts.c", "../include/uts.h";
  extern proc uts_printParams(): void;

  proc print_settings(): void
  {
    uts_printParams();
  }

  proc print_results(const sizePerLocale: [0..#numLocales] int, const numLeafPerLocale: [0..#numLocales] int,
    const timer: Timer, const maxDepthPerLocale: [0..#numLocales] int): void
  {
    var size: int = (+ reduce sizePerLocale);
    var numLeaf: int = (+ reduce numLeafPerLocale);
    var maxDepth: int = (max reduce maxDepthPerLocale);

    writeln("\n=================================");
    writeln("Size of the explored tree: ", size);
    /* writeln("Size of the explored tree per locale: ", sizePerLocale); */
    writeln("% of the explored tree per locale: ", 100 * sizePerLocale:real / size:real);
    writeln("Number of leaves explored: ", numLeaf, " (", 100 * numLeaf:real / size:real, "%)");
    /* writeln("Number of explored solutions per locale: ", numLeafPerLocale); */
    writeln("Tree depth: ", maxDepth);
    writeln("Elapsed time: ", timer.elapsed(TimeUnits.seconds), " [s]");
    writeln("=================================\n");
  }

  proc uts_helpMessage(): void
  {
    writeln("\n  UTS Benchmark Parameters:\n");
    writeln("   --t   int       tree type (0: BIN, 1: GEO, 2: HYBRID, 3: BALANCED)");
    writeln("   --b   double    root branching factor");
    writeln("   --r   int       root seed 0 <= r < 2^31");
    writeln("   --a   int       GEO: tree shape function \n");
    writeln("   --d   int       GEO, BALANCED: tree depth\n");
    writeln("   --q   double    BIN: probability of non-leaf node");
    writeln("   --m   int       BIN: number of children for non-leaf node");
    writeln("   --f   double    HYBRID: fraction of depth for GEO -> BIN transition");
    writeln("   --g   int       granularity: number of rng_spawns per node");
  }
}
