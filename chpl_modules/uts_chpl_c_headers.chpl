module uts_chpl_c_headers
{
	use CTypes;

	require "../c_sources/uts.c", "../c_headers/uts.h";
	require "../c_sources/aux.c", "../c_headers/aux.h";
	//require "../src/rng/brg_sha1.c", "../src/rng/brg_sha1.h";
	//require "../src/rng/alfg.c", "../src/rng/alfg.h";

	extern type tree_t;
	extern type geoshape_t;

	// Tree type
	pragma "locale private" extern var treeType: tree_t;
	pragma "locale private" extern var b_0: c_double;
	pragma "locale private" extern var rootId: c_int;
	// bin distribution
	pragma "locale private" extern var nonLeafBF: c_int;
	pragma "locale private" extern var nonLeafProb: c_double;
	// geo distribution
	pragma "locale private" extern var gen_mx: c_int;
	pragma "locale private" extern var shape_fn: geoshape_t;
	// hybrid distribution
	pragma "locale private" extern var shiftDepth: c_double;
	// granularity
	pragma "locale private" extern var computeGranularity: c_int;

	extern record Node {}

	extern proc uts_initRoot(ref root: Node, dist: c_int): void;
	extern proc uts_numChildren(ref parent: Node): c_int;
	/* extern proc uts_childType(ref parent: Node): c_int; */

	extern proc decompose(ref parent: Node, children: c_ptr(Node), computeGranularity: c_int,
		ref treeSize: int, ref nbLeaf: int, ref maxDepth: int): void;

	extern proc castTo_tree_t(const a: c_int): tree_t;
	extern proc castTo_geoshape_t(const a: c_int): geoshape_t;

	extern proc save_time(numTasks: c_int, time: c_double, path: c_string): void;
}
