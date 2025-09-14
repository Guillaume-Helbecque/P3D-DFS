module Node_QubitAlloc
{
  use Util;

  config param sizeMax: uint(8) = 27;

  record Node_QubitAlloc
  {
    var mapping: sizeMax*int(8);
    var lower_bound: int(32);
    var depth: uint(32);
    var available: [0..<sizeMax] bool;

    var domCost: domain(1, idxType = uint(8));
    var costs: [domCost] int(32);
    var domLeader: domain(1, idxType = uint(8));
    var leader: [domLeader] int(32);
    var size: int(32);

    // default-initializer
    proc init()
    {}

    // root-initializer
    proc init(problem)
    {
      init this;
      for i in 0..<problem.n do this.mapping[i] = -1:int(8);
      this.available = true;

      this.domCost = {0..<(problem.N**4)};
      this.domLeader = {0..<(problem.N**2)};
      this.size = problem.N;
      Assemble(problem.D, problem.F, problem.N);
    }

    // copy-initializer
    proc init(other: Node_QubitAlloc)
    {
      this.mapping = other.mapping;
      this.lower_bound = other.lower_bound;
      this.depth = other.depth + 1;
      this.available = other.available;

      const m = other.size - 1;
      this.domCost = {0..<(m**4)}; // other.domCost;
      this.costs = noinit; //other.costs;
      this.domLeader = {0..<(m**2)}; //other.domLeader;
      this.leader = noinit; //other.leader;
      this.size = m;
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
