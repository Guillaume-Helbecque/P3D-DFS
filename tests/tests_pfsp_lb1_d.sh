#!/usr/bin/env bash
set -euo pipefail

# Known optimal makespan
declare -A instances=(
  ["ta003"]=1081
  ["ta004"]=1293
  ["ta007"]=1234
  ["ta009"]=1230
  ["ta011"]=1582
  ["ta012"]=1659
  ["ta013"]=1496
  ["ta014"]=1377
  ["ta015"]=1419
  ["ta016"]=1397
  ["ta019"]=1593
)

# Upper bounds to test
ubs=("opt")

for inst in "${!instances[@]}"; do
  expected="${instances[$inst]}"

  for ub in "${ubs[@]}"; do
    echo "======================================"
    echo "Instance=$inst LB=lb1_d UB=$ub (expected=$expected)"

    cmd="../main_pfsp.out --mode sequential --inst $inst --lb lb1_d --ub $ub"

    # Run solver with timeout protection
    if ! output=$(timeout 60s $cmd); then
      echo "FAIL (timeout or crash)"
      exit 1
    fi

    # Extract optimal makespan from solver output
    result=$(echo "$output" \
      | grep -i "optimal makespan" \
      | sed -E 's/.*makespan: ([0-9]+).*/\1/')

    # Validate parsing
    if [ -z "$result" ]; then
      echo "FAIL (could not parse makespan)"
      exit 1
    fi

    if ! [[ "$result" =~ ^[0-9]+$ ]]; then
      echo "FAIL (invalid makespan: $result)"
      exit 1
    fi

    # Check correctness against expected optimum
    if [ "$result" -ne "$expected" ]; then
      echo "FAIL (expected $expected, got $result)"
      exit 1
    fi

    echo "Result: $result"
    echo "PASS"
  done
done

echo "All PFSP tests with LB1_d passed!"
