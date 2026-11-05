#!/usr/bin/env bash

# This files contains the optimal solutions of a small subset of Pisinger instances

declare -A instances=(
  # uncorrelated
  ["KP1"]="knapPI_1_50_10000_72"
  # weakly correlated
  ["KP2"]="knapPI_2_100_1000_74"
  # strongly correlated
  ["KP3"]="knapPI_3_100_1000_83"
  # inverse strongly correlated
  ["KP4"]="knapPI_4_100_1000_12"
  # almost strongly correlated
  ["KP5"]="knapPI_5_100_10000000_84"
  # subset sum
  ["KP6"]="knapPI_6_50_100000_9"
  # uncorrelated with similar weights
  ["KP7"]="knapPI_9_100_100000_13"
  # uncorrelated spanner, span(2,10)
  ["KP8"]="knapPI_11_100_1000_22"
  # weakly correlated spanner, span(2,10)
  ["KP9"]="knapPI_12_100_1000_3"
  # strongly correlated spanner, span(2,10)
  ["KP10"]="knapPI_13_100_1000_3"
  # multiple strongly correlated, mstr(3R/10,2R/10,6)
  ["KP11"]="knapPI_14_100_1000_78"
  # profit ceiling, pceil(3)
  ["KP12"]="knapPI_15_100_1000_15"
  # circle, circle(2/3)
  ["KP13"]="knapPI_16_100_1000_53"
)

declare -A instances_optimum=(
  ["KP1"]=226213
  ["KP2"]=39516
  ["KP3"]=53897
  ["KP4"]=7060
  ["KP5"]=463031649
  ["KP6"]=230644
  ["KP7"]=1107418
  ["KP8"]=37111
  ["KP9"]=1700
  ["KP10"]=1760
  ["KP11"]=52434
  ["KP12"]=8442
  ["KP13"]=51112
)
