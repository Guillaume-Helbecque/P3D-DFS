module main_qubitAlloc
{
  use Subprocess;

  // Common modules
  use util;

  // Problem-specific modules
  use Problem_QubitAlloc;

  // Common options
  config const mode: string    = "multicore"; // sequential, multicore, distributed
  config const activeSet: bool = false;
  config const saveTime: bool  = false;

  // Problem-specific option
  config const inter = "10_sqn";
  config const dist = "16_melbourne";
  config const itmax: int(32) = 10;
  config const ub: string = "heuristic";  // heuristic

  proc chooseSmallestType(const ref D, const ref F, const N)
  {
    var maxVal = 0;

    for i in 0..<N {
      for j in 0..<N {
        for k in 0..<N {
          for l in 0..<N {
            if !((k == i) ^ (l == j)) then
              maxVal = max(maxVal, F[i, k] * D[j, l]);
          }
        }
      }
    }

    writeln("maxVal = ", maxVal);

    if (maxVal <= max(uint(8))) then return "'uint(8)'";
    else if (maxVal <= max(uint(16))) then return "'uint(16)'";
    else if (maxVal <= max(uint(32))) then return "'uint(32)'";
    else return "'uint(64)'";
  }

  proc main(args: [] string): int
  {
    // Initialization of the problem
    var qubitAlloc = new Problem_QubitAlloc(inter, dist, itmax, ub);

    var optimalType = chooseSmallestType(qubitAlloc.D, qubitAlloc.F, qubitAlloc.N);

    writeln(optimalType);

    try! {
      var sub = spawn(["make", "main_qubitAlloc.out", "_CHPL_QUBIT_ALLOC_BIT_OPT=-seltType="+optimalType]);
      sub.wait();
      /* begin with (ref sub) {
        sub = spawn([
          "./main_qubitAlloc.out",
          "--mode="+mode,
          "--activeSet="+activeSet:string,
          "--saveTime="+saveTime:string,
          "--inter="+inter,
          "--dist="+dist,
          "--itmax="+itmax:string,
          "--ub="+ub,
          ]);
      }
      sub.wait();
      sub = spawn(["rm", "main_qubitAlloc.out"]); */
    }

    return 0;
  }
}
