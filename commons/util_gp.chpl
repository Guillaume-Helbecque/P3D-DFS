module util_gp
{
  use Map;
  use List;
  use Regex;

  // === Primitive set =========================================================

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

  // === GP tree compilation procedures ========================================

  // Map from string to (function, arity)
  var operations = new map(string, BinaryRealOp);
  operations.add("add", __add);
  operations.add("sub", __sub);
  operations.add("mul", __mul);
  operations.add("protecteddiv", __protecteddiv);

  proc exprToProc(expr, getDepth, getLowerbound, getNVars): int
  {
    var context = new map(string, real);
    context.add("getDepth", getDepth:real);
    context.add("getLowerbound", getLowerbound);
    context.add("getNVars", getNVars:real);
    context.add("10000000", 10000000.0);

    return evaluateExpr(expr, context):int;
  }

  proc evaluateExpr(expr, context): real
  {
    try! {
      // Regex to match outermost function calls
      const re = new regex("^(\\w+)\\((.*)\\)$");
      var name, args_str: string;

      if re.match(expr, name, args_str).matched {
        if checkName(name) {
          var args = parseArgs(args_str, context);
          /* NOTE: the following works because we supposed binary operations. */
          return operations.get(name, __add)(args[0], args[1]);
        }
        else halt("Unsupported operation name");
      }
      else {
        try! {
          return expr:real;
        }
        catch e: IllegalArgumentError {
          return context[expr];
        }
      }
    }
  }

  proc parseArgs(args, context): list(real)
  {
    var args_list: list(string);
    var nested, last_split = 0;

    for (char, i) in zip(args.items(), 0..) {
      if char == '(' then nested += 1;
      else if char == ')' then nested -= 1;
      else if char == ',' && nested == 0 {
        args_list.pushBack(args[last_split..(i-1)].strip());
        last_split = i + 1;
      }
    }
    args_list.pushBack(args[last_split..].strip());

    var l: list(real);
    for arg in args_list do
      l.pushBack(evaluateExpr(arg, context));

    return l;
  }

  proc checkName(name): bool
  {
    for n in operations.keys() {
      if name == n then return true;
    }
    return false;
  }
}
