module Header_chpl_c_PFSP
{
	use CTypes;

	require "c_sources/c_bound_simple.c", "c_headers/c_bound_simple.h";

	extern record bound_data {};

	extern proc new_bound_data(_jobs: c_int, _machines: c_int): c_ptr(bound_data);
	extern proc free_bound_data(const b: c_ptr(bound_data)): void;
	extern proc fill_min_heads_tails(const data: c_ptr(bound_data)): void;
	extern proc eval_solution(const data: c_ptr(bound_data), const permutation: c_ptr(c_int)): c_int;
	extern proc lb1_bound(data: c_ptr(bound_data), const permutation: c_ptr(c_int), const limit1:c_int, const limit2: c_int): c_int;
	extern proc lb1_children_bounds(const data: c_ptr(bound_data), const permutation: c_ptr(c_int), const limit1:c_int, const limit2: c_int,
		const lb_begin: c_ptr(c_int), const lb_end: c_ptr(c_int), const prio_begin: c_ptr(c_int), const prio_end: c_ptr(c_int), const direction: c_int): void;

	require "c_sources/c_bound_johnson.c", "c_headers/c_bound_johnson.h";

	extern record johnson_bd_data {};

	extern proc new_johnson_bd_data(const lb1: c_ptr(bound_data)/*, lb2_type: lb2_variant*/): c_ptr(johnson_bd_data);
	extern proc free_johnson_bd_data(b: c_ptr(johnson_bd_data)): void;
	extern proc fill_machine_pairs(b: c_ptr(johnson_bd_data)/*, lb2_type: lb2_variant*/): void;
	extern proc fill_lags(const lb1: c_ptr(bound_data), const lb2: c_ptr(johnson_bd_data)): void;
	extern proc fill_johnson_schedules(const lb1: c_ptr(bound_data), const lb2: c_ptr(johnson_bd_data)): void;
	extern proc lb2_bound(const lb1: c_ptr(bound_data), const lb2: c_ptr(johnson_bd_data), const permutation: c_ptr(c_int),
		const limit1:c_int, const limit2:c_int, const best_cmax:c_int): c_int;

	require "c_sources/c_taillard.c", "c_headers/c_taillard.h";

	extern proc taillard_get_nb_jobs(const inst_id: c_int): c_int;
	extern proc taillard_get_nb_machines(const inst_id: c_int): c_int;
	/* extern proc taillard_get_processing_times(b: c_ptr(bound_data), const id: c_int): void; */

	require "c_sources/fill_times.c", "c_headers/fill_times.h";

	extern proc taillard_get_processing_times_d(b: c_ptr(bound_data), const id: c_int): void;

	/* require "../../commons/c_sources/aux.c", "../../commons/c_headers/aux.h";

  extern proc swap(ref a: c_int, ref b: c_int): void; */
}
