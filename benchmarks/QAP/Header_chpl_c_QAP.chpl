module Header_chpl_c_QAP
{
	use CTypes;

	require "c_headers/c_wrappers.h";

	extern "bound_GLB_wrapper" proc bound_GLB(mapping: c_ptr(c_int), available: c_ptr(c_int),
		depth: c_int, F: c_ptr(c_int), D: c_ptr(c_int), n: c_int, N: c_int): int(64);

	extern record RLT_WarmData_wrapper {};

	extern proc RLT_WarmData_wrapper_new(): c_ptr(RLT_WarmData_wrapper);
	extern proc RLT_WarmData_wrapper_free(w: c_ptr(RLT_WarmData_wrapper)): void;

	extern "bound_RLT1_wrapper" proc bound_RLT1(const mapping: c_ptrConst(c_int),
		const available: c_ptrConst(c_int), depth: c_int, const F: c_ptrConst(c_int),
		const D: c_ptrConst(c_int), n: c_int, N: c_int, rlt_itmax: c_int, rlt_tol: c_double,
		ref best: int(64), opt_solution: c_ptr(c_int), const warm: c_ptrConst(RLT_WarmData_wrapper),
		warm_branch_fac: c_int, warm_branch_loc: c_int, out_warm: c_ptr(RLT_WarmData_wrapper)): int(64);
}
