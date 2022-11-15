module fsp_simple_chpl_c_headers
{
	use CTypes;

	require "../src/c_bound_simple.c", "../include/c_bound_simple.h";

	extern record bound_data {};

	extern proc new_bound_data(_jobs: c_int, _machines: c_int): c_ptr(bound_data);
	extern proc fill_min_heads_tails(const data: c_ptr(bound_data)): void;
	extern proc eval_solution(const data: bound_data, const permutation: c_ptr(c_int)): c_int;
	extern proc lb1_bound(const data: c_ptr(bound_data), const permutation: c_ptr(c_int), const limit1:c_int, const limit2: c_int): c_int;
	extern proc lb1_children_bounds(const data: c_ptr(bound_data), const permutation: c_ptr(c_int), const limit1:c_int, const limit2: c_int,
		const lb_begin: c_ptr(c_int), const lb_end: c_ptr(c_int), const prio_begin: c_ptr(c_int), const prio_end: c_ptr(c_int), const direction: c_int): void;
	extern proc free_bound_data(const b: c_ptr(bound_data)): void;

	require "../src/c_taillard.c", "../include/c_taillard.h";

	extern proc taillard_get_nb_jobs(const inst_id: c_int): c_int;
	extern proc taillard_get_nb_machines(const inst_id: c_int): c_int;
	/* extern proc taillard_get_processing_times(ptm: c_ptr(c_int), const id: c_int): void; */

	require "../src/fill_times.c", "../include/fill_times.h";

	extern proc taillard_get_processing_times_d(b: c_ptr(bound_data), const id: c_int): void;

	require "../src/aux.c", "../include/aux.h";

	extern proc save_time(numThreads: c_int, time: c_double, path: c_string): void;
}
