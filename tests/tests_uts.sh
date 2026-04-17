#!/usr/bin/env bash
set -euo pipefail

# ==============================
# UTS test configurations
# ==============================

declare -A configs=(
  # Geometric [fixed]
  [T1]="--t 1 --a 3 --d 10 --b 4 --r 19"
  # Geometric [linear dec.]
  [T2]="--t 1 --a 0 --d 20 --b 4 --r 34"
  # Geometric [cyclic]
  [T3]="--t 1 --a 2 --d 16 --b 6 --r 502"
  # Binomial
  [T4]="--t 0 --b 2000 --q 0.124875 --m 8 --r 42"
  # Hybrid
  [T5]="--t 2 --a 0 --d 16 --b 6 --r 1 --q 0.234375 --m 4 --r 1"
  # Binomial
  [T6]="--t 0 --b 2000 --m 2 --q 0.499995 --r 30"
  # Geometric [fixed]
  [T7]="--t 1 --a 3 --d 13 --b 4 --r 29"
  # Geometric [cyclic]
  [T8]="--t 1 --a 2 --d 23 --b 7 --r 220"
  # Binomial
  [T9]="--t 0 --b 2000 --q 0.200014 --m 5 --r 7"
)

# ==============================
# Expected results
# ==============================

declare -A expected_size=(
  [T1]=4130071
  [T2]=4147582
  [T3]=4117769
  [T4]=4112897
  [T5]=4132453
  [T6]=51747899
  [T7]=102181082
  [T8]=96793510
  [T9]=111345631
)

declare -A expected_depth=(
  [T1]=10
  [T2]=20
  [T3]=81
  [T4]=1572
  [T5]=134
  [T6]=16604
  [T7]=13
  [T8]=67
  [T9]=17844
)

declare -A expected_leaves=(
  [T1]=3305118
  [T2]=2181318
  [T3]=2342762
  [T4]=3599034
  [T5]=3108986
  [T6]=25874949
  [T7]=81746377
  [T8]=53791152
  [T9]=89076904
)

# ==============================
# Tests
# ==============================

for key in "${!configs[@]}"; do
  args="${configs[$key]}"

  echo "======================================"
  echo "Testing $key"
  echo "Args: $args"

  # Run solver
  if ! output=$(timeout 60s ../main_uts.out --mode sequential $args); then
    echo "FAIL $key (timeout or crash)"
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
    echo "FAIL $key (parsing error)"
    exit 1
  fi

  # Check correctness
  if [ "$size" -ne "${expected_size[$key]}" ]; then
    echo "FAIL $key (tree size)"
    echo "Expected: ${expected_size[$key]}, Got: $size"
    exit 1
  fi

  if [ "$leaves" -ne "${expected_leaves[$key]}" ]; then
    echo "FAIL $key (leaves)"
    echo "Expected: ${expected_leaves[$key]}, Got: $leaves"
    exit 1
  fi

  if [ "$depth" -ne "${expected_depth[$key]}" ]; then
    echo "FAIL $key (depth)"
    echo "Expected: ${expected_depth[$key]}, Got: $depth"
    exit 1
  fi

  echo "PASS $key"
done

echo "All UTS tests passed!"
