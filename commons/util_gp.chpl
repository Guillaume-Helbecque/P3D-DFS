module util_gp
{
  use Map;

  // Define function signatures
  type BinaryRealOp = proc(a: real, b: real): real;
  /*
    NOTE: For the moment, only binary real operations are supported.
    TODO: - Support unary and ternary operations (e.g., neg)
          - Support integer operations (e.g., mod)
  */

  // Mathematical operations
  proc __add(a: real, b: real): real do return a + b;
  proc __sub(a: real, b: real): real do return a - b;
  proc __mul(a: real, b: real): real do return a * b;
  proc __protecteddiv(a: real, b: real): real do return if b == 0.0 then 1.0 else a / b;
  proc __pow(a: real, b: real): real do return a ** b;
  /* proc __mod(a: real, b: real): real do return a % b; */
  proc __neg(a: real): real do return -a;
  proc __pos(a: real): real do return +a;

  // Comparison operations
  proc __lt(a: real, b: real): real do return (a < b):real;
  proc __le(a: real, b: real): real do return (a <= b):real;
  proc __eq(a: real, b: real): real do return (a == b):real;
  proc __ne(a: real, b: real): real do return (a != b):real;
  proc __ge(a: real, b: real): real do return (a >= b):real;
  proc __gt(a: real, b: real): real do return (a > b):real;

  // Map from string to (function, arity)
  var primitives = new map(string, (BinaryRealOp, int));
  primitives.add("add", (__add, 2));
  primitives.add("sub", (__sub, 2));
  primitives.add("mul", (__mul, 2));
  primitives.add("protecteddiv", (__protecteddiv, 2));
  /* primitives.add("pow", (__pow, 2)); */
  /* primitives.add("mod", (__mod, 2)); */
  /* primitives.add("neg", (__neg, 1)); */
  /* primitives.add("pos", (__pos, 1)); */

  /* primitives.add("lt", (__lt, 2)); */
  /* primitives.add("le", (__le, 2)); */
  /* primitives.add("eq", (__eq, 2)); */
  /* primitives.add("ne", (__ne, 2)); */
  /* primitives.add("ge", (__ge, 2)); */
  /* primitives.add("gt", (__gt, 2)); */
}
