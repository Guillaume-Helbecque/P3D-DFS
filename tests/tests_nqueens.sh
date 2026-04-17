#!/usr/bin/env bash
set -euo pipefail

# Known number of solutions
declare -A expected=(
  [1]=1
  [2]=0
  [3]=0
  [4]=2
  [5]=10
  [6]=4
  [7]=40
  [8]=92
  [9]=352
  [10]=724
  [11]=2680
  [12]=14200
  [13]=73712
  [14]=365596
  [15]=2279184
)

for N in $(seq 1 15); do
  echo "=============================="
  echo "Testing N=$N (expected=${expected[$N]})"

  # Run solver
  if ! output=$(timeout 120s ../main_nqueens.out --mode sequential --N "$N"); then
    echo "FAIL N=$N (timeout or crash)"
    exit 1
  fi

  # Extract number of solutions (robust parsing)
  result=$(echo "$output" \
    | grep -i "^Number of explored solutions" \
    | sed -E 's/.*: ([0-9]+).*/\1/')

  # Validate parsing
  if [ -z "$result" ]; then
    echo "FAIL N=$N (could not parse result)"
    exit 1
  fi

  if ! [[ "$result" =~ ^[0-9]+$ ]]; then
    echo "FAIL N=$N (invalid result: $result)"
    exit 1
  fi

  # Check correctness
  if [ "$result" -ne "${expected[$N]}" ]; then
    echo "FAIL N=$N"
    echo "Expected: ${expected[$N]}"
    echo "Got: $result"
    exit 1
  fi

  echo "PASS N=$N"
done

echo "All N-Queens tests passed!"
