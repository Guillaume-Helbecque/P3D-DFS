#!/usr/bin/env bash
set -euo pipefail

source ./instances_knapsack.sh

tests=(
  "KP1"
  "KP2"
  "KP3"
  "KP4"
  "KP5"
  "KP6"
  "KP7"
  "KP8"
  "KP9"
  "KP10"
  "KP11"
  "KP12"
  "KP13"
)

# Lower bounds to test
lbs=("opt")

cd ..

for key in "${tests[@]}"; do
  args="${instances[$key]}"
  expected="${instances_optimum[$key]}"

  for lb in "${lbs[@]}"; do
    echo "======================================"
    echo "Testing $key ($args)"

    # Run solver
    if ! output=$(timeout 60s ./main_knapsack.out --mode sequential --ub martello --lb $lb $args); then
      echo "FAIL (timeout or crash)"
      exit 1
    fi

    # Extract values
    result=$(echo "$output" \
      | grep -i "Optimum found" \
      | sed -E 's/.*found: ([0-9]+).*/\1/')

    # Validate parsing
    if [ -z "$result" ]; then
      echo "FAIL (parsing error)"
      exit 1
    fi

    if ! [[ "$result" =~ ^[0-9]+$ ]]; then
      echo "FAIL (invalid optimum: $result)"
      exit 1
    fi

    # Check correctness
    if [ "$result" -ne "$expected" ]; then
      echo "FAIL (expected $expected, got $result)"
      exit 1
    fi

    echo "PASS"
  done
done

echo "All Knapsack tests with Martello bound passed!"
