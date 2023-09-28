module Header_chpl_c_UTS
{
	use CTypes;
	use Node_UTS;

	require "c_sources/uts.c", "c_headers/uts.h";

	extern const uts_trees_str: c_ptr(c_ptrConst(c_char));
	extern const uts_geoshapes_str: c_ptr(c_ptrConst(c_char));

	extern proc uts_numChildren(const ref parent: Node_UTS, treeType: c_int, nonLeafBF: c_int,
		nonLeafProb: c_double, b_0: c_double, shape_fn: c_int, gen_mx: c_int, shiftDepth: c_double): c_int;

	extern proc c_decompose(const ref parent: Node_UTS, children: c_ptr(Node_UTS), treeType: c_int,
		numChildren: c_int, gen_mx: c_int, shiftDepth: c_double, computeGranularity: c_int,
		ref treeSize: int, ref maxDepth: int): void;
}
