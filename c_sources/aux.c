#include "../c_headers/aux.h"
#include "../c_headers/fsp_gen.h"
#include <limits.h>
#include <stdlib.h>
#include <stdio.h>

void remplirTempsArriverDepart(int *minTempsArr, int *minTempsDep,
    const int machines, const int jobs, const int *times)
{
    int t0, tmin;

    minTempsArr[0] = 0;

    for (int m = 1; m < machines; m++){ // for machines
        tmin = INT_MAX;
        // find smallest date a job can start on m
        for (int j = 0; j < jobs; j++){
            t0 = 0;
            for (int mm = 0; mm < m; mm++){
                t0 += times[mm * jobs + j];
            }
            if (t0 < tmin) tmin = t0;
        }
        minTempsArr[m] = tmin;
    }

    minTempsDep[machines-1] = 0;

    for (int m = machines-2; m >= 0; m--){ // for machines
        tmin = INT_MAX;
        // find smallest date a job can start on m
        for (int j = 0; j < jobs; j++){
            t0 = 0;
            for (int mm = machines-1; mm > m; mm--){
                t0 += times[mm * jobs + j];
            }
            if (t0 < tmin) tmin = t0;
        }
        minTempsDep[m] = tmin;
    }
}

// Print subproblem
void print_subsol(int *permutation, int depth)
{
    printf("\nSubsolution: \n" );
    for (int i = 0; i < depth; ++i){
        printf(" %d - ",permutation[i]);
    }
    printf("\n");
}

// Print permutation
void print_permutation(int *permutation, int jobs)
{
    printf("\nPermutation: \n" );
    for (int i = 0; i < jobs; ++i){
        printf(" %d - ", permutation[i]);
    }
    printf("\n");
}

// Print the instance
void print_instance(int machines, int jobs, int *times)
{
    //scanf("%d", &upper_bound);
    printf("\nInstance (M x J): \n\n%2d x %2d\n", machines, jobs);

    for (int m = 0; m < machines; m++){
        for (int j = 0; j < jobs; ++j){
            printf(" %2d ", times[m * jobs + j]);
        }
        printf("\n");
    }
}

// Fill the initial permutation
void start_vector(int *permutation, int jobs)
{
    for (int i = 0; i < jobs; ++i){
        permutation[i] = i;
    }
}

// Swap two integers
void swap(int *a, int *b)
{
    int tmp = *b;
    *b = *a;
    *a = tmp;
}

// Max between two integers
int max(int a, int b)
{
    return (a > b) ? a : b;
}

// Generate the time matrix of the instance
int* get_instance(int *machines, int *jobs, short inst_num)
{
    // // int m, j, i;
    //
    // //scanf("%d", &upper_bound);
    // int *times = (int*)(malloc(sizeof(int)*5000));
    // generate_flow_shop(inst_num, times, machines, jobs);
    //
    // // write_problem(inst_num,instance);
    //
    // // for (i = 0; i < ( m * j ); i++) {
    // //     scanf("%d", &instance[i]);
    // // }
    //
    // // (*machines) = m;
    // // (*jobs) = j;
    //
    // return times;
}

void save_time(const int numThreads, const double time, const char *path)
{
  FILE *f = fopen(path, "a");
  fprintf(f, "%d %f\n", numThreads, time);
  fclose(f);
}
