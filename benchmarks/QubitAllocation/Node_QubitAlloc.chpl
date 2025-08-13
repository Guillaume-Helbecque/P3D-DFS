module Node_QubitAlloc
{
  use IO;
  use List;
  use CTypes;

  config param sizeMax: int = 27;

  class CostMatrix {
    var domCost: domain(1);
    var costs: [domCost] c_int;
    var domLeader: domain(1);
    var leader: [domLeader] c_int;
    var size: int;

    proc init() {
      /* init this;
      domCost = 0..0;
      costs[0] = 0;
      domCost = 0..0;
      leader[0] = 0;
      size = 0; */
    }

    proc init(D, F, N) {
      init this;
      this.domCost = 0..<(N**4);
      this.domLeader = 0..<(N**2);
      this.size = N;
      Assemble(D, F, N);
    }

  }

  proc idx4D(i, j, k, l, n)
  {
    return n*n*n*i + n*n*j + n*k + l;
  }

  record Node_QubitAlloc
  {
    var mapping: c_array(c_int, sizeMax);
    /* var cost: c_int; */
    var lower_bound: c_int;
    var depth: c_int;
    var available: list(int);
    /* var costMatrix: owned CostMatrix; */

    var domCost: domain(1);
    var costs: [domCost] c_int;
    var domLeader: domain(1);
    var leader: [domLeader] c_int;
    var size: int;

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
      this.mapping[0..<problem.n] = -1:c_int;
      this.available.pushBack(0..<problem.N);

      this.domCost = 0..<(problem.N**4);
      this.domLeader = 0..<(problem.N**2);
      this.size = problem.N;
      Assemble(problem.D, problem.F, problem.N);
    }

    // copy-initializer
    proc init(other: Node_QubitAlloc)
    {
    }

    proc deinit()
    {}

    proc Assemble(D, F, N)
    {
      const inf: c_int = max(c_int) / 2;

      /* for (i,j,k,l) in zip(0..<N,0..<N,0..<N,0..<N) {

      } */

      for i in 0..<N
      {
        for j in 0..<N
        {
          for k in 0..<N
          {
            for l in 0..<N
            {
              if ((k == i) ^ (l == j)) then
                this.costs[idx4D(i, j, k, l, N)] = inf;
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
