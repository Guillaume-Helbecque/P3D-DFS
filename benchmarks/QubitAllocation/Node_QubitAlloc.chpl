module Node_QubitAlloc
{
  use List;

  use Util;

  config param sizeMax: int(32) = 27;

  /* class CostMatrix {
    var domCost: domain(1);
    var costs: [domCost] c_int;
    var domLeader: domain(1);
    var leader: [domLeader] c_int;
    var size: int;

    proc init() {}

    proc init(D, F, N) {
      init this;
      this.domCost = 0..<(N**4);
      this.domLeader = 0..<(N**2);
      this.size = N;
      Assemble(D, F, N);
    }
  } */

  record Node_QubitAlloc
  {
    var mapping: sizeMax*int(32);
    /* var cost: c_int; */
    var lower_bound: int(32);
    var depth: int(32);
    var available: list(int(32));
    /* var costMatrix: owned CostMatrix; */

    var domCost: domain(1, idxType = int(32));
    var costs: [domCost] int(32);
    var domLeader: domain(1, idxType = int(32));
    var leader: [domLeader] int(32);
    var size: int(32);

    // default-initializer
    proc init()
    {
      /* this.costMatrix = new CostMatrix(); */
    }

    // root-initializer
    proc init(problem)
    {
      /* this.costMatrix = new CostMatrix(problem.D, problem.F, problem.N); */
      init this;
      for i in 0..<problem.n do this.mapping[i] = -1:int(32);
      this.available.pushBack(0..<problem.N);

      this.domCost = 0..<(problem.N**4);
      this.domLeader = 0..<(problem.N**2);
      this.size = problem.N;
      Assemble(problem.D, problem.F, problem.N);
    }

    // copy-initializer
    proc init(other: Node_QubitAlloc)
    {
      this.mapping = other.mapping;
      this.lower_bound = other.lower_bound;
      this.depth = other.depth;
      this.available = other.available;

      this.domCost = other.domCost;
      this.costs = other.costs;
      this.domLeader = other.domLeader;
      this.leader = other.leader;
      this.size = other.size;
    }

    proc deinit()
    {}

    proc ref Assemble(D, F, N)
    {
      for i in 0..<N {
        for j in 0..<N {
          for k in 0..<N {
            for l in 0..<N {
              if ((k == i) ^ (l == j)) then
                this.costs[idx4D(i, j, k, l, N)] = INFD2;
              else
                this.costs[idx4D(i, j, k, l, N)] = F[i, k] * D[j, l];
            }
          }
          this.leader[i*N + j] = this.costs[idx4D(i, j, i, j, N)];
        }
      }
    }
  }

}
