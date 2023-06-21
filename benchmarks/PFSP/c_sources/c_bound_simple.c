#include <limits.h>
#include <string.h>
#include "../c_headers/c_bound_simple.h"

bound_data* new_bound_data(const int jobs, const int machines)
{
    bound_data *b = malloc(sizeof(bound_data));

    if (b) {
        b->p_times = malloc(jobs*machines*sizeof(int));
        b->min_heads = malloc(machines*sizeof(int));
        b->min_tails = malloc(machines*sizeof(int));
        b->nb_jobs = jobs;
        b->nb_machines = machines;
    }

    return b;
}

void free_bound_data(bound_data* b)
{
    if (b) {
        free(b->min_tails);
        free(b->min_heads);
        free(b->p_times);
        free(b);
    }
}

inline void
add_forward(const int job, const int * const p_times, const int nb_jobs, const int nb_machines, int * front)
{
    front[0] += p_times[job];
    for (int j = 1; j < nb_machines; j++) {
        front[j] = MAX(front[j-1], front[j]) + p_times[j * nb_jobs + job];
    }
}

inline void
add_backward(const int job, const int * const p_times, const int nb_jobs, const int nb_machines, int * back)
{
    int j = nb_machines - 1;
    back[j] += p_times[j * nb_jobs + job];

    for (int j = nb_machines - 2; j >= 0; j--) {
        back[j] = MAX(back[j], back[j+1]) + p_times[j * nb_jobs + job];
    }
}

void
schedule_front(const bound_data* const data, const int * const permut, const int limit1, int * front)
{
    const int N = data->nb_jobs;
    const int M = data->nb_machines;
    const int *const p_times = data->p_times;

    if (limit1 == -1) {
        for (int i = 0; i < M; i++)
            front[i] = data->min_heads[i];
        return;
    }
    for (int i = 0; i < M; i++){
        front[i] = 0;
    }
    for (int i = 0; i < limit1+1; i++) {
        add_forward(permut[i], p_times, N, M, front);
    }
}

void
schedule_back(const bound_data* const data, const int * const permut, const int limit2, int * back)
{
    const int N = data->nb_jobs;
    const int M = data->nb_machines;
    const int *const p_times = data->p_times;

    if (limit2 == N) {
        for (int i = 0; i < M; i++)
            back[i] = data->min_tails[i];
        return;
    }

    for (int i = 0; i < M; i++){
        back[i] = 0;
    }
    for (int k = N-1; k >= limit2; k--) {
        add_backward(permut[k], p_times, N, M, back);
    }
}

int eval_solution(const bound_data* const data, const int* const permutation)
{
    int N = data->nb_jobs;
    int M = data->nb_machines;
    int tmp[N];

    for (int i = 0; i < N; i++) {
        tmp[i] = 0;
    }
    for (int i = 0; i < N; i++) {
        add_forward(permutation[i], data->p_times, N, M, tmp);
    }

    return tmp[M-1];
}

void
sum_unscheduled(const bound_data* const data, const int * const permut, const int limit1, const int limit2, int * remain)
{
    int N = data->nb_jobs;
    int M = data->nb_machines;
    int *p_times = data->p_times;

    for (int j = 0; j < M; j++) {
        remain[j] = 0;
    }
    for (int k = limit1 + 1; k < limit2; k++) {
        int job = permut[k];
        for (int j = 0; j < M; j++) {
            remain[j] += p_times[j * N + job];
        }
    }
}

int
machine_bound_from_parts(const int * const front, const int * const back, const int * const remain,
  const int nb_machines)
{
    int tmp = front[0] + remain[0];
    int lb  = tmp + back[0]; // LB on machine 0

    for (int i = 1; i < nb_machines; i++) {
        tmp = MAX(tmp, front[i] + remain[i]);
        lb  = MAX(lb, tmp + back[i]);
    }

    return lb;
}

int
lb1_bound(const bound_data* const data, const int * const permut, const int limit1, const int limit2)
{
    int M = data->nb_machines;

    int front[M];
    int back[M];
    int remain[M];

    schedule_front(data, permut, limit1, front);
    schedule_back(data, permut, limit2, back);
    sum_unscheduled(data, permut, limit1, limit2, remain);

    return machine_bound_from_parts(front, back, remain, M);
}

void lb1_children_bounds(const bound_data *const data, const int *const permutation, const int limit1, const int limit2, int *const lb_begin, int *const lb_end, int *const prio_begin, int *const prio_end, const int direction)
{
    int N = data->nb_jobs;
    int M = data->nb_machines;

    int front[M];
    int back[M];
    int remain[M];

    schedule_front(data, permutation, limit1, front);
    schedule_back(data, permutation, limit2, back);
    sum_unscheduled(data, permutation, limit1, limit2, remain);

    switch (direction) {
        case -1: //begin
        {
            memset(lb_begin, 0, N*sizeof(int));
            if (prio_begin) memset(prio_begin, 0, N*sizeof(int));

            for (int i = limit1+1; i < limit2; i++) {
                int job = permutation[i];
                lb_begin[job] = add_front_and_bound(data, job, front, back, remain, prio_begin);
            }
            break;
        }
        case 0: //begin-end
        {
            memset(lb_begin, 0, N*sizeof(int));
            memset(lb_end, 0, N*sizeof(int));
            if (prio_begin) memset(prio_begin, 0, N*sizeof(int));
            if (prio_end) memset(prio_end, 0, N*sizeof(int));

            for (int i = limit1+1; i < limit2; i++) {
                int job = permutation[i];
                lb_begin[job] = add_front_and_bound(data, job, front, back, remain, prio_begin);
                lb_end[job]   = add_back_and_bound(data, job, front, back, remain, prio_end);
            }
            break;
        }
        case 1: //end
        {
            memset(lb_end, 0, N*sizeof(int));
            if (prio_end) memset(prio_end, 0, N*sizeof(int));

            for (int i = limit1+1; i < limit2; i++) {
                int job = permutation[i];
                lb_end[job]   = add_back_and_bound(data, job, front, back, remain, prio_end);
            }
            break;
        }
    }
}

// adds job to partial schedule in front and computes lower bound on optimal cost
// NB1: schedule is no longer needed at this point
// NB2: front, remain and back need to be set before calling this
// NB3: also compute total idle time added to partial schedule (can be used a criterion for job ordering)
// nOps : m*(3 add+2 max)  ---> O(m)
int
add_front_and_bound(const bound_data* const data, const int job, const int * const front, const int * const back, const int * const remain, int *delta_idle)
{
    int N = data->nb_jobs;
    int M = data->nb_machines;
    int* p_times = data->p_times;

    int lb  = front[0] + remain[0] + back[0];
    int tmp = front[0] + p_times[job];

    int idle = 0;
    for (int i = 1; i < M; i++) {
        idle += MAX(0, tmp - front[i]);

        tmp  = MAX(tmp, front[i]);
        lb   = MAX(lb, tmp + remain[i] + back[i]);
        tmp += p_times[i * N + job];
    }

    //can pass NULL
    if (delta_idle)
        delta_idle[job] = idle;

    return lb;
}

// ... same for back
int
add_back_and_bound(const bound_data* const data, const int job, const int * const front, const int * const back, const int * const remain, int *delta_idle)
{
    int N = data->nb_jobs;
    int M = data->nb_machines;
    int* p_times = data->p_times;

    int last_machine = M - 1;

    int lb  = front[last_machine] + remain[last_machine] + back[last_machine];
    int tmp = back[last_machine] + p_times[last_machine * N + job];

    int idle = 0;
    for (int i = last_machine-1; i >= 0; i--) {
        idle += MAX(0, tmp - back[i]);

        tmp = MAX(tmp, back[i]);
        lb  = MAX(lb, tmp + remain[i] + front[i]);
        tmp += p_times[i * N + job];
    }

    //can pass NULL
    if (delta_idle)
        delta_idle[job] = idle;

    return lb;
}

void
fill_min_heads_tails(bound_data* data)
{
    const int N = data->nb_jobs;
    const int M = data->nb_machines;
    const int *const p_times = data->p_times;

    // 1/ min start times on each machine
    data->min_heads[0] = 0; // per definition =0 on first machine
    for (int k = 1; k < M; k++) data->min_heads[k] = INT_MAX;

    int tmp;
    for (int i = 0; i < N; i++) {
        tmp = p_times[i];
        for (int k = 1; k < M; k++) {
            tmp += p_times[k * N + i];
            data->min_heads[k] = MIN(data->min_heads[k], tmp);
        }
    }

    // 2/ min run-out times on each machine
    for (int k = 0; k < M-1; k++) data->min_tails[k] = INT_MAX;
    data->min_tails[M-1] = 0; // per definition =0 on last machine

    for (int i = 0; i < N; i++) {
        tmp = p_times[(M - 1) * N + i];

        for (int k = M-2; k >= 0; k--) {
            data->min_tails[k] = MIN(data->min_tails[k], tmp);
            tmp += p_times[k * N + i];;
        }
    }
}

// #ifdef __cplusplus
// }
// #endif
