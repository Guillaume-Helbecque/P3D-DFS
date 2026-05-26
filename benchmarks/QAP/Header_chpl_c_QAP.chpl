module Header_chpl_c_QAP
{
	use CTypes;

	require "c_headers/c_wrappers.h";

	extern "bound_GLB_wrapper" proc bound_GLB(mapping: c_ptr(c_int), available: c_ptr(c_int),
		depth: c_int, F: c_ptr(c_int), D: c_ptr(c_int), n: c_int, N: c_int): int(64);

	extern "bound_IGLB_wrapper" proc bound_IGLB(mapping: c_ptr(c_int), available: c_ptr(c_int),
		depth: c_int, F: c_ptr(c_int), D: c_ptr(c_int), n: c_int, N: c_int): int(64);

	extern "bound_EVB_wrapper" proc bound_EVB(mapping: c_ptr(c_int), available: c_ptr(c_int),
		depth: c_int, F: c_ptr(c_int), D: c_ptr(c_int), n: c_int, N: c_int, ub: int(64)): int(64);

	extern record RLT_WarmData_wrapper {};

	extern proc RLT_WarmData_wrapper_new(): c_ptr(RLT_WarmData_wrapper);
	extern proc RLT_WarmData_wrapper_free(w: c_ptr(RLT_WarmData_wrapper)): void;

	extern "bound_RLT1_wrapper" proc bound_RLT1(const mapping: c_ptrConst(c_int),
		const available: c_ptrConst(c_int), depth: c_int, const F: c_ptrConst(c_int),
		const D: c_ptrConst(c_int), n: c_int, N: c_int, rlt_itmax: c_int, rlt_tol: c_double,
		ref best: int(64), opt_solution: c_ptr(c_int), const warm: c_ptrConst(RLT_WarmData_wrapper),
		warm_branch_fac: c_int, warm_branch_loc: c_int, out_warm: c_ptr(RLT_WarmData_wrapper)): int(64);

	extern "bound_RLT2_wrapper" proc bound_RLT2(const mapping: c_ptrConst(c_int),
		const available: c_ptrConst(c_int), depth: c_int, const F: c_ptrConst(c_int),
		const D: c_ptrConst(c_int), n: c_int, N: c_int, rlt_itmax: c_int, rlt_tol: c_double,
		ref best: int(64), opt_solution: c_ptr(c_int), const warm: c_ptrConst(RLT_WarmData_wrapper),
		warm_branch_fac: c_int, warm_branch_loc: c_int, out_warm: c_ptr(RLT_WarmData_wrapper)): int(64);

	extern record QPB_ParentContext {};

	extern proc QPB_ParentContext_new(
		const parent_mapping: c_ptrConst(c_int), const parent_available: c_ptrConst(c_int),
		parent_depth: c_int, branch_fac_i: c_int,
		const F: c_ptrConst(c_int), const D: c_ptrConst(c_int), n: c_int, N: c_int,
		qpb_maxFW: c_int, qpb_tol: c_double,
		parent_qpb_has_data: c_int, parent_qpb_m: c_int,
		const parent_qpb_X: c_ptrConst(c_double),
		const parent_qpb_reduced_costs: c_ptrConst(c_double),
		const parent_qpb_unassigned_fac: c_ptrConst(c_int),
		const parent_qpb_unassigned_loc: c_ptrConst(c_int),
		parent_qpb_fixed_cost: int(64),
		parent_qpb_bound_cont_last: c_double,
		f_symmetric: c_int, d_symmetric: c_int): c_ptr(QPB_ParentContext);

	extern proc QPB_ParentContext_free(ctx: c_ptr(QPB_ParentContext)): void;

	extern proc bound_QPB_child(
		ctx: c_ptr(QPB_ParentContext), branch_loc_j: c_int, UB: int(64),
		out_qpb_X: c_ptr(c_double), out_qpb_reduced_costs: c_ptr(c_double),
		out_qpb_unassigned_fac: c_ptr(c_int), out_qpb_unassigned_loc: c_ptr(c_int),
		ref out_qpb_m: c_int, ref out_qpb_has_data: c_int,
		ref out_qpb_bound_cont: c_double, ref out_qpb_bound_cont_last: c_double,
		ref out_qpb_fixed_cost: int(64)): int(64);

	extern proc is_symmetric_matrix_c(const M: c_ptrConst(c_int), n: c_int, N: c_int): c_int;
}
