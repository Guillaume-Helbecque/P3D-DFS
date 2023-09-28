module Node_UTS
{
  use CTypes;

  require "c_sources/uts.c", "c_headers/uts.h";
  extern proc uts_initRoot(ref root: Node_UTS, treeType: c_int, rootId: c_int): void;

  extern record Node_UTS
  {
    var numChildren: c_int;

    // default-initializer
    proc init()
    {}

    // root-initializer
    proc init(problem)
    {
      init this;
      uts_initRoot(this, problem.treeType, problem.rootId);
    }
  }
}
