module Util
{
  import Node_QubitAlloc.eltType;

  param INF: eltType = max(eltType);
  param INFD2: eltType = INF / 2;

  proc idx4D(i, j, k, l, n)
  {
    return n**3*i + n**2*j + n*k + l;
  }

  proc ckmin(ref a, const ref b)
  {
    if (b < a) {
      a = b;
      return true;
    }

    return false;
  }

  proc localLogicalQubitIndex(const mapping, i)
  {
    var j, k: int(32);

    while (j < i) {
      if (mapping[j] == -1) then
        k += 1;

      j += 1;
    }

    return k;
  }

  proc localPhysicalQubitIndex(const ref av, j)
  {
    var l: int(32);

    for i in 0..<j {
      if av[i] then
        l += 1;
    }

    return l;
  }
}
