/*
  Encodes a permutation of n elements into a Lehmer code represented as a 64-bit
  unsigned integer. The Lehmer code uniquely identifies the permutation in a
  factorial number system.
*/
proc encode_lehmer(const ref p, const n): uint(64)
{
  var vals, rank, a: [0..#32] int;
  var fact: [0..#32] uint(64);
  var lehmer: uint(64);

  for i in 0..<n {
    vals[i] = p[i];
  }

  for i in 0..<(n-1) {
    for j in (i+1)..<n {
      if (vals[j] < vals[i]) {
        vals[i] <=> vals[j];
      }
    }
  }

  for i in 0..<n {
    rank[i] = -1;
  }

  for i in 0..<n {
    for j in 0..<n {
      if (p[j] == vals[i]) {
        a[j] = i;
        break;
      }
    }
  }

  fact[0] = 1;
  for i in 1..n {
    fact[i] = fact[i-1] * i;
  }

  for i in 0..<n {
    var ai = a[i];
    var smaller = 0;
    for j in (i+1)..<n {
      if (a[j] < ai) then
        smaller += 1;
    }

    lehmer += smaller:uint(64) * fact[n-1-i];
  }

  return lehmer;
}

/*
  Decodes a Lehmer code back into the original permutation of n elements.
*/
proc decode_lehmer(lehmer: uint(64), const n, ref perm)
{
  var elements: [0..<n] int(32);
  for i in 0..<n do elements[i] = i:int(32);
  var fact: [0..#32] uint(64);
  var dom: domain(1, idxType = uint(64)) = {0:uint(64)..<32:uint(64)};
  var seq: [dom] int(32);

  fact[0] = 1;
  for i in 1..n do
    fact[i] = fact[i - 1] * i;

  for i in 0..<n {
    seq[i] = elements[i];
  }

  var x: uint(64) = lehmer;

  for i in 0..<n by -1 {
    var idx: uint(64);
    if (i == 0) {
      idx = 0;
    }
    else {
      idx = x / fact[i];
      x = x % fact[i];
    }
    perm[n-1-i] = seq[idx];

    if i > 0 {
      for k in idx..<i {
        seq[k] = seq[k+1];
      }
    }
  }
}
