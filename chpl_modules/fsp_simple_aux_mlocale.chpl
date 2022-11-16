module fsp_simple_aux_mlocale
{
  use CTypes;
  use fsp_simple_chpl_c_headers;

	proc fsp_simple_all_locales_get_instance(ref local_times: [] c_int, machines: c_int, jobs: c_int)
	{
  	coforall loc in Locales do on loc {
  		forall i in 0..#machines*jobs do c_temps_s[i] = local_times[i];
		}
		//writeln("Instance loaded on locales.");
	}

	proc fsp_simple_all_locales_init_data(machines: c_int, jobs: c_int)
	{
    coforall loc in Locales do on loc { // but locale one -- let's put it
      remplirTempsArriverDepart(minTempsArr_s, minTempsDep_s, machines, jobs, c_temps_s);
    }
		//writeln("Data loaded on locales.");
	}

	proc fsp_simple_all_locales_print_instance(machines: c_int, jobs: c_int)
	{
  	for loc in Locales do on loc {
    	writeln("Instance on Locale #", here.id);
    	print_instance(machines, jobs, c_temps_s);
    	writeln("\n\n\n");
    }
	}

	proc fsp_simple_all_locales_print_minTempsArr(machines: c_int)
	{
    for loc in Locales do on loc { // but locale one -- let's put it
      writeln("MinTempsArr on Locale #", here.id);
      for i in 0..#machines do writeln(minTempsArr_s[i]);
      writeln("\n\n\n");
    }
	}

	proc fsp_simple_all_locales_print_minTempsDep(machines: c_int)
	{
    for loc in Locales do on loc { // but locale one -- let's put it
      writeln("MinTempsDep on Locale #", here.id);
      for i in 0..#machines do writeln(minTempsDep_s[i]);
      writeln("\n\n\n");
    }
	}

}
