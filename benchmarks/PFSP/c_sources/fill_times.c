#include "../c_headers/fill_times.h"

void taillard_get_processing_times_d(bound_data *d, const int id)
{
    int N = taillard_get_nb_jobs(id);
    int M = taillard_get_nb_machines(id);
    long time_seed = time_seeds[id - 1];
    //
    if(!d->p_times){
        d->p_times = malloc(N*M*sizeof(int));
    }

    for(int i=0;i<M;i++){
        for(int j=0;j<N;j++){
            d->p_times[i*N+j] = (int)unif(&time_seed, 1, 99);
        }
    }
}
