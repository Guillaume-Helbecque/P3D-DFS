#include "../c_headers/objective.hpp"


longint Objective(const vector<int>& mapping, const vector<int>& F,
                  const vector<int>& D, int n, int N)
{
    longint cost = 0;
    for (int i = 0; i < n; ++i)
    {
        if (mapping[i] == -1) continue;
        for (int j = 0; j < n; ++j)
        {
            if (mapping[j] == -1) continue;
            cost += (longint)F[i * N + j] * D[mapping[i] * N + mapping[j]];
        }
    }
    return cost;
}
