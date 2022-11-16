module fsp_johnson_aux_mlocale
{
	use CTypes;
  use fsp_johnson_chpl_c_headers;

	proc fsp_johnson_all_locales_get_instance(ref local_times: [] c_int, machines: c_int, jobs: c_int)
	{
  	coforall loc in Locales do on loc {
  		forall i in 0..#machines*jobs do c_temps[i] = local_times[i];
    }
		//writeln("Instance loaded on locales.");
	}

	proc fsp_johnson_all_locales_init_data(machines: c_int, jobs: c_int)
	{
    coforall loc in Locales do on loc { //but locale one -- let's put it
  		johnson_remplirMachine(machines, machine);
      remplirTempsArriverDepart(minTempsArr, minTempsDep, machines, jobs, c_temps);
      johnson_remplirLag(machines, jobs, machine, tempsLag,c_temps);
      johnson_remplirTabJohnson(machines, jobs, tabJohnson, tempsLag, c_temps);
    }
		//writeln("Data loaded on locales.");
	}

	proc fsp_johnson_all_locales_print_instance(machines: c_int, jobs: c_int)
	{
  	for loc in Locales do on loc {
    	writeln("Instance on Locale #", here.id);
    	print_instance(machines, jobs, c_temps);
    	writeln("\n\n\n");
    }
	}

	proc fsp_johnson_all_locales_print_machine(machines: c_int)
	{
  	for loc in Locales do on loc { //but locale one -- let's put it
      writeln("Machines on Locale #", here.id);
      for i in 0..#machines do writeln(machine[i]);
      writeln("\n\n\n");
    }
	}

	proc fsp_johnson_all_locales_print_minTempsArr(machines: c_int)
	{
    for loc in Locales do on loc { //but locale one -- let's put it
      writeln("MinTempsArr on Locale #", here.id);
      for i in 0..#machines do writeln(minTempsArr[i]);
      writeln("\n\n\n");
    }
	}

	proc fsp_johnson_all_locales_print_minTempsDep(machines: c_int)
	{
    for loc in Locales do on loc { //but locale one -- let's put it
      writeln("MinTempsDep on Locale #", here.id);
      for i in 0..#machines do writeln(minTempsDep[i]);
      writeln("\n\n\n");
    }
	}

	proc fsp_johnson_all_locales_print_tabJohnson(jobs: c_int)
	{
    for loc in Locales do on loc { //but locale one -- let's put it
      writeln("TabJohnson on Locale #", here.id);
      for i in 0..#jobs do writeln(tabJohnson[i]);
      writeln("\n\n\n");
    }
	}

}
