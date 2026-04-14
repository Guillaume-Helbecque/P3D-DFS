#!/usr/bin/env bash
set -e

declare -A expected
expected[1]=1
expected[2]=0
expected[3]=0
expected[4]=2
expected[5]=10
expected[6]=4
expected[7]=40
expected[8]=92
expected[9]=352
expected[10]=724
expected[11]=2680
expected[12]=14200
expected[13]=73712
expected[14]=365596
expected[15]=2279184

for N in $(seq 1 15); do
  echo "=============================="
  echo "Testing N=$N"

  if ! result=$(timeout 120s ../main_nqueens.out --mode sequential --N $N \
    | grep "Number of explored solutions" \
    | awk '{print $NF}');
  then
    echo "FAIL N=$N (timeout or crash)"
    exit 1
  fi

  if [ -z "$result" ]; then
    echo "FAIL N=$N (no output)"
    exit 1
  fi

  if [ "$result" != "${expected[$N]}" ]; then
    echo "FAIL N=$N"
    echo "Expected: ${expected[$N]}"
    echo "Got: $result"
    exit 1
  fi

  echo "PASS N=$N"
done

echo "All N-Queens tests passed!"
