#!/usr/bin/env bash
set -euo pipefail

source ./instances_nqueens.sh

Nmin=1
Nmax=15

for N in $(seq $Nmin $Nmax); do
  expected="${instances[$N]}"

  echo "=============================="
  echo "Testing N=$N (expected=$expected)"

  # Run solver
  if ! output=$(timeout 60s ../main_nqueens.out --mode sequential --N "$N"); then
    echo "FAIL (timeout or crash)"
    exit 1
  fi

  # Extract number of solutions (robust parsing)
  result=$(echo "$output" \
    | grep -i "^Number of explored solutions" \
    | sed -E 's/.*: ([0-9]+).*/\1/')

  # Validate parsing
  if [ -z "$result" ]; then
    echo "FAIL (could not parse result)"
    exit 1
  fi

  if ! [[ "$result" =~ ^[0-9]+$ ]]; then
    echo "FAIL (invalid result: $result)"
    exit 1
  fi

  # Check correctness
  if [ "$result" -ne "$expected" ]; then
    echo "FAIL (expected $expected, got $result)"
    exit 1
  fi

  echo "PASS"
done

echo "All N-Queens tests passed!"
