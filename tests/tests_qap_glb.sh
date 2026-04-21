#!/usr/bin/env bash
set -euo pipefail

source ./instances_qap.sh

tests=(
  "chr12a"
  "chr12b"
  "chr12c"
  "chr15a"
  "chr15b"
  "chr15c"
  "chr18a"
  "chr18b"
  "chr20a"
  "chr20b"
  "chr20c"
  "chr22a"
  "chr22b"
  "had12"
  "had14"
  "had16"
  "nug12"
  "nug14"
  "nug15"
  "nug16a"
  "nug16b"
  "rou12"
  "rou15"
  "scr12"
  "scr15"
  "tai12a"
  "tai12b"
  "tai15a"
  "tai15b"
  "10_sqn,16_melbourne"
  "10_sym9,16_melbourne"
  "11_sym9,16_melbourne"
  "11_wim,16_melbourne"
  "11_z4,16_melbourne"
  "12_cycle10,16_melbourne"
  "12_rd84,16_melbourne"
  "12_sym9,16_melbourne"
  "13_dist,16_melbourne"
  "13_radd,16_melbourne"
  "13_root,16_melbourne"
  "14_clip,16_melbourne"
  "14_cm42a,16_melbourne"
  "14_cm85a,16_melbourne"
  "15_co14,16_melbourne"
  "15_misex1,16_melbourne"
  "15_sqrt7,16_melbourne"
  "16_inc,16_melbourne"
  "16_ising,16_melbourne"
)

# Upper bounds to test
ubs=("heuristic")

cd ..

for inst in "${tests[@]}"; do
  expected="${instances[$inst]}"

  for ub in "${ubs[@]}"; do
    echo "======================================"
    echo "Instance=$inst LB=glb UB=$ub (expected=$expected)"

    cmd="./main_qap.out --mode sequential --inst $inst --lb glb --ub $ub"

    # Run solver with timeout protection
    if ! output=$(timeout 60s $cmd); then
      echo "FAIL (timeout or crash)"
      exit 1
    fi

    # Extract optimal allocation from solver output
    result=$(echo "$output" \
      | grep -i "optimal allocation" \
      | sed -E 's/.*allocation: ([0-9]+).*/\1/')

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

echo "All QAP tests with GLB passed!"
