use fsp_simple_m_bound_single_node;
use fsp_simple_mn_bound_single_node;
use fsp_johnson_bound_single_node;

use fsp_simple_m_bound_multi_node;
use fsp_simple_mn_bound_multi_node;
use fsp_johnson_bound_multi_node;

/* use uts_multi_node; */
use uts_single_node;

use aux;

config const problem: string = "uts"; // uts, fsp

// FSP instance
config const instance: int(8) = 3; // between 1 and 120
// FSP lower bound function
config const lb: string = "simple_mn"; // simple_mn, johnson, simple_m
// FSP branching rule
config const side: int = 0; // forward (0), backward (1)
// Execution mode
config const mode: string = "multi"; // single, multi

// Display options
config const printExploredTree: bool = true; // number of explored nodes
config const printExploredSol: bool = true; // number of explored solutions
config const printMakespan: bool = true; // best makespan

// Debugging options
config const dbgProfiler: bool = false;
config const dbgDiagnostics: bool = false;
config const activeSet: bool = false;

// Postprocessing options
config const saveTime: bool = false;

proc main(args: [] string): int
{
  // Helper
  for a in args[1..] {
    if (a == "-h" || a == "--help") {
      helpMessage();

      return 1;
    }
  }

  select problem {
    when "fsp" {
      select mode {
        when "single" {
          select lb {
            when "simple_mn" {
              fsp_simple_mn_search_single_node(instance, side, dbgProfiler, dbgDiagnostics,
                printExploredTree, printExploredSol, printMakespan, lb, saveTime);
            }
            when "simple_m" {
              fsp_simple_m_search_single_node(instance, side, dbgProfiler, dbgDiagnostics,
                printExploredTree, printExploredSol, printMakespan, lb, saveTime);
            }
            when "johnson" {
              fsp_johnson_search_single_node(instance, side, dbgProfiler, dbgDiagnostics,
                printExploredTree, printExploredSol, printMakespan, lb, saveTime);
            }
            otherwise {
              halt("ERROR - Unknown lower bound");
            }
          }
        }
        when "multi" {
          select lb {
            when "simple_mn" {
              fsp_simple_mn_search_multi_node(instance, side, dbgProfiler, dbgDiagnostics,
                printExploredTree, printExploredSol, printMakespan, lb, saveTime, activeSet);
            }
            when "simple_m" {
              fsp_simple_m_search_multi_node(instance, side, dbgProfiler, dbgDiagnostics,
                printExploredTree, printExploredSol, printMakespan, lb, saveTime, activeSet);
            }
            when "johnson" {
              fsp_johnson_search_multi_node(instance, side, dbgProfiler, dbgDiagnostics,
                printExploredTree, printExploredSol, printMakespan, lb, saveTime, activeSet);
            }
            otherwise {
              halt("ERROR - Unknown lower bound");
            }
          }
        }
        otherwise {
          halt("ERROR - Unknown mode");
        }
      }
    }
    when "uts" {
      select mode {
        when "single" {
          uts_single_node(dbgProfiler, dbgDiagnostics);
        }
        when "multi" {
          /* uts_multi_node(dbgProfiler, dbgDiagnostics); */
        }
        otherwise {
          halt("ERROR - Unknown mode");
        }
      }
    }
    otherwise {
      halt("ERROR - Unknown problem");
    }
  }

  return 0;
}
