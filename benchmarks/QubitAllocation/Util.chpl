module Util
{
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
