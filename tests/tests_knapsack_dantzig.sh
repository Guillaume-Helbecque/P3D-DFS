#!/usr/bin/env bash
set -euo pipefail

# ==============================
# Knapsack test configurations
# ==============================

declare -A configs=(
  # uncorrelated
  [KP1]="--t 1 --n 50 --r 10000 --id 72"
  # weakly correlated
  [KP2]="--t 2 --n 100 --r 1000 --id 74"
  # strongly correlated
  [KP3]="--t 3 --n 100 --r 1000 --id 83"
  # inverse strongly correlated
  [KP4]="--t 4 --n 100 --r 1000 --id 12"
  # almost strongly correlated
  [KP5]="--t 5 --n 100 --r 10000000 --id 84"
  # subset sum
  [KP6]="--t 6 --n 50 --r 100000 --id 9"
  # uncorrelated with similar weights
  [KP7]="--t 9 --n 100 --r 100000 --id 13"
  # uncorrelated spanner, span(2,10)
  [KP8]="--t 11 --n 100 --r 1000 --id 22"
  # weakly correlated spanner, span(2,10)
  [KP9]="--t 12 --n 100 --r 1000 --id 3"
  # strongly correlated spanner, span(2,10)
  [KP10]="--t 13 --n 100 --r 1000 --id 3"
  # multiple strongly correlated, mstr(3R/10,2R/10,6)
  [KP11]="--t 14 --n 100 --r 1000 --id 78"
  # profit ceiling, pceil(3)
  [KP12]="--t 15 --n 100 --r 1000 --id 15"
  # circle, circle(2/3)
  [KP13]="--t 16 --n 100 --r 1000 --id 53"
)

# ==============================
# Expected results
# ==============================

declare -A optimum=(
  [KP1]=226213
  [KP2]=39516
  [KP3]=53897
  [KP4]=7060
  [KP5]=463031649
  [KP6]=230644
  [KP7]=1107418
  [KP8]=37111
  [KP9]=1700
  [KP10]=1760
  [KP11]=52434
  [KP12]=8442
  [KP13]=51112
)

# ==============================
# Tests
# ==============================

# Lower bounds to test
lbs=("opt")

cd ..

for key in "${!configs[@]}"; do
  args="${configs[$key]}"
  expected="${optimum[$key]}"

  for lb in "${lbs[@]}"; do
    echo "======================================"
    echo "Testing $key"
    echo "Args: $args"

    # Run solver
    if ! output=$(timeout 60s ./main_knapsack.out --mode sequential --ub dantzig --lb $lb $args); then
      echo "FAIL $key (timeout or crash)"
      exit 1
    fi

    # Extract values
    result=$(echo "$output" \
      | grep -i "Optimum found" \
      | sed -E 's/.*found: ([0-9]+).*/\1/')

    # Validate parsing
    if [ -z "$result" ]; then
      echo "FAIL $key (parsing error)"
      exit 1
    fi

    if ! [[ "$result" =~ ^[0-9]+$ ]]; then
      echo "FAIL (invalid optimum: $result)"
      exit 1
    fi

    # Check correctness
    if [ "$result" -ne "${expected}" ]; then
      echo "FAIL $key (expected $expected, got $result)"
      exit 1
    fi

    echo "PASS $key"
  done
done

echo "All Knapsack tests with Dantzig bound passed!"
