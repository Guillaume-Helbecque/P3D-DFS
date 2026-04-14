module Header_chpl_c_QAP
{
	use CTypes;

	require "c_headers/bound_glb.h";

	extern "bound_GLB_wrapper" proc bound_GLB(mapping: c_ptr(c_int), available: c_ptr(c_int),
		depth: c_int, F: c_ptr(c_int), D: c_ptr(c_int), n: c_int, N: c_int): int(64);
}
