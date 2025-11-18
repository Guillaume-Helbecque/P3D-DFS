#!/bin/bash -l
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=128
#SBATCH --time=1-00:00:00
#SBATCH --exclusive
#SBATCH --exclude=aion-0207,aion-0016

results_file="results_best_itmax.csv"

for j in {1..50}; do

  prev_time=-1

  for i in {2..20}; do

    output=$(./main_qap.out --mode sequential --inst F_${j},16_melbourne --itmax ${i} 2>&1)

    printf '%s\n' "$output"

    current_time=$(echo "$output" | grep "Elapsed time" | tail -1 | awk '{print $3}')

    echo -e "$j\t$i\t$current_time" >> "$results_file"

    if (( $(echo "$prev_time > 0 && $current_time >= $prev_time" | bc -l) )); then
      break
    fi

    prev_time=$current_time
  done
done
