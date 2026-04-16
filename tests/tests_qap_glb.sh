#!/usr/bin/env bash
set -euo pipefail

# Known optimal makespan
declare -A instances=(
  # QAPLIB
  ["chr12a"]=9552
  ["chr12b"]=9742
  ["chr12c"]=11156
  ["chr15a"]=9896
  ["chr15b"]=7990
  ["chr15c"]=9504
  ["chr18a"]=11098
  ["chr18b"]=1534
  ["chr20a"]=2192
  ["chr20b"]=2298
  ["chr20c"]=14142
  ["chr22a"]=6156
  ["chr22b"]=6194
  ["had12"]=1652
  ["had14"]=2724
  ["had16"]=3720
  ["nug12"]=578
  ["nug14"]=1014
  ["nug15"]=1150
  ["nug16a"]=1610
  ["nug16b"]=1240
  ["rou12"]=235528
  ["rou15"]=354210
  ["scr12"]=31410
  ["scr15"]=51140
  ["tai12a"]=224416
  ["tai12b"]=39464925
  ["tai15a"]=388214
  ["tai15b"]=51765268
  # Qubit Allocation
  ["10_sqn,16_melbourne"]=6140
  ["10_sym9,16_melbourne"]=13904
  ["11_sym9,16_melbourne"]=23936
  ["11_wim,16_melbourne"]=480
  ["11_z4,16_melbourne"]=2140
  ["12_cycle10,16_melbourne"]=4688
  ["12_rd84,16_melbourne"]=9864
  ["12_sym9,16_melbourne"]=196
  ["13_dist,16_melbourne"]=31682
  ["13_radd,16_melbourne"]=2484
  ["13_root,16_melbourne"]=13514
  ["14_clip,16_melbourne"]=33412
  ["14_cm42a,16_melbourne"]=836
  ["14_cm85a,16_melbourne"]=10678
  ["15_co14,16_melbourne"]=10824
  ["15_misex1,16_melbourne"]=3188
  ["15_sqrt7,16_melbourne"]=3072
  ["16_inc,16_melbourne"]=8318
  ["16_ising,16_melbourne"]=0
)

# Upper bounds to test
ubs=("heuristic")

cd ..

for inst in "${!instances[@]}"; do
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

    echo "Result: $result"
    echo "PASS"
  done
done

echo "All QAP tests with GLB passed!"
