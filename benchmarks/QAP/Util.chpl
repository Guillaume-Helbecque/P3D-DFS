module Util
{
  param INF: int = max(int);
  param INF32: int(32) = max(int(32));
  param INFD2: int = max(int) / 2;

  proc idx4D(i, j, k, l, n)
  {
    return (n*n*n*i + n*n*j + n*k + l):int(32);
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
      if (av[i]) then
        l += 1;
    }

    return l;
  }
}
