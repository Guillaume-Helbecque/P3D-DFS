#!/usr/bin/env bash
set -euo pipefail

source ./instances_pfsp.sh

tests=(
  "ta003"
  "ta004"
  "ta007"
  "ta009"
  "ta011"
  "ta012"
  "ta013"
  "ta014"
  "ta015"
  "ta019"
)

# Upper bounds to test
ubs=("opt")

for inst in "${tests[@]}"; do
  expected="${instances[$inst]}"

  for ub in "${ubs[@]}"; do
    echo "======================================"
    echo "Instance=$inst LB=lb2 UB=$ub (expected=$expected)"

    cmd="../main_pfsp.out --mode sequential --inst $inst --lb lb2 --ub $ub"

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

    echo "PASS"
  done
done

echo "All PFSP tests with LB2 passed!"
