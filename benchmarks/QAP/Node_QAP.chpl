module Node_QAP
{
  use Util;

  config param sizeMax: int(32) = 27;

  record Node_QAP_HHB
  {
    var mapping: sizeMax*int(32);
    var lower_bound: int(32);
    var depth: uint(8);
    var available: [0..<sizeMax] bool;

    var domCost: domain(1, idxType = int(32));
    var costs: [domCost] int(32);
    var domLeader: domain(1, idxType = int(32));
    var leader: [domLeader] int(32);
    var size: int(32);

    // default-initializer
    proc init()
    {}

    // root-initializer
    proc init(problem)
    {
      init this;
      for i in 0..<problem.n do this.mapping[i] = -1;
      this.available = true;

      this.domCost = {0..<(problem.N**4)};
      this.domLeader = {0..<(problem.N**2)};
      this.size = problem.N;
      Assemble(problem.D, problem.F, problem.N);
    }

    // copy-initializer
    proc init(other: Node_QAP_HHB)
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

  record Node_QAP_GLB
  {
    var mapping: sizeMax*int(32);
    var depth: uint(8);
    var available: [0..<sizeMax] bool;

    // default-initializer
    proc init()
    {}

    // root-initializer
    proc init(problem)
    {
      init this;
      for i in 0..<problem.n do this.mapping[i] = -1;
      this.available = true;
    }

    // copy-initializer
    proc init(other: Node_QAP_GLB)
    {
      this.mapping = other.mapping;
      this.depth = other.depth;
      this.available = other.available;
    }
  }
}
