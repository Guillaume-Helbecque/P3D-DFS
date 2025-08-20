module Util
{
  param INF: int(32) = max(int(32));
  param INFD2: int(32) = max(int(32)) / 2;

  proc idx4D(i, j, k, l, n)
  {
    return (n*n*n*i + n*n*j + n*k + l):int(32);
  }

  proc getLocalIndex(mapping, i)
  {
    var j, k: int(32);

    while (j < i)
    {
      if (mapping[j] == -1) then
        k += 1;

      j += 1;
    }

    return k;
  }
}
