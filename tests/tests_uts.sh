#!/usr/bin/env bash
set -euo pipefail

source ./instances_uts.sh

tests=(
  "T1"
  "T2"
  "T3"
  "T4"
  "T5"
  "T6"
  "T7"
  "T8"
  "T9"
)

for key in "${tests[@]}"; do
  args="${instances[$key]}"
  expected_size="${instances_size[$key]}"
  expected_leaves="${instances_leaves[$key]}"
  expected_depth="${instances_depth[$key]}"

  echo "======================================"
  echo "Testing $key ($args)"

  # Run solver
  if ! output=$(timeout 60s ../main_uts.out --mode sequential $args); then
    echo "FAIL (timeout or crash)"
    exit 1
  fi

  # Extract values
  size=$(echo "$output" \
    | grep -i "Size of the explored tree" \
    | sed -E 's/.*: ([0-9]+).*/\1/')

  leaves=$(echo "$output" \
    | grep -i "Number of leaves explored" \
    | sed -E 's/.*: ([0-9]+).*/\1/')

  depth=$(echo "$output" \
    | grep -i "Tree depth" \
    | sed -E 's/.*: ([0-9]+).*/\1/')

  # Validate parsing
  if [ -z "$size" ] || [ -z "$leaves" ] || [ -z "$depth" ]; then
    echo "FAIL (parsing error)"
    exit 1
  fi

  # Check correctness
  if [ "$size" -ne "$expected_size" ]; then
    echo "FAIL (tree size: expected $expected_size, got $size)"
    exit 1
  fi

  if [ "$leaves" -ne "$expected_leaves" ]; then
    echo "FAIL (leaves: expected $expected_leaves, got $leaves)"
    exit 1
  fi

  if [ "$depth" -ne "$expected_depth" ]; then
    echo "FAIL (depth: expected $expected_depth, got $depth)"
    exit 1
  fi

  echo "PASS"
done

echo "All UTS tests passed!"
