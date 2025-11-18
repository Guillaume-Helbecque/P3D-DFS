#!/bin/bash -l

results_file="results_best_itmax.csv"

for j in {1..100}; do

  prev_time=-1

  for i in {2..20}; do

    output=$(./main_qap.out --mode sequential --inst 10_sqn,16_melbourne --itmax ${i} 2>&1 | tee /dev/tty)

    current_time=$(echo "$output" | grep "Elapsed time" | tail -1 | awk '{print $3}')

    echo -e "$j\t$i\t$current_time" >> "$results_file"

    if (( $(echo "$prev_time > 0 && $current_time >= $prev_time" | bc -l) )); then
      break
    fi

    prev_time=$current_time
  done
done
